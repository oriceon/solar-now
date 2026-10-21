#!/usr/bin/env python3
"""Loads the widget outside Plasma, with stand-ins for the Plasma modules, and saves a screenshot.

    viewer.py stage  out.png [--lang en] [--mode login] [--latest '{"generation": 3200}']
    viewer.py stage  out.png --animations full --expect-motion       # fails unless the dots and an icon move
    viewer.py stage  out.png --tab 2 --scale year                    # a tab: 0 flow, 1 day, 2 history, 3 balance, 4 alerts, 5 device
    viewer.py applet out.png --mock --tab 1                          # the same tab, loaded by the real stores from the stand-in API
    viewer.py applet out.png --mock                                  # real main.qml against a local stand-in for Deye Cloud
    viewer.py applet out.png --mock --stale-token                    # the token on hand is refused: it has to be renewed
    viewer.py config out.png --page 0 --mock --connect secret        # type the password, press Connect, report what is kept
    viewer.py config out.png --page 0 --mock --connected --expect-stations 2   # reopened settings: the stations are listed again

Exits with 1 when QML reported an error or a warning, so a broken binding does not go unnoticed.
"""

import argparse
import ctypes
import hashlib
import json
import os
import sys
import threading
import xml.etree.ElementTree as ElementTree
from datetime import date, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# No core dump if Qt crashes: in a container that shares the kernel of the desktop, the dump goes to
# the crash handler of the desktop, which reports a crash of its own Python on the screen.
ctypes.CDLL(None, use_errno=True).prctl(4, 0, 0, 0, 0)

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import Q_ARG, QElapsedTimer, QMetaObject, QTimer, QUrl, QtMsgType, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlListReference, qmlRegisterSingletonType, qmlRegisterType
from PySide6.QtQuick import QQuickItem, QQuickView
from shiboken6 import getCppPointer

import shim_kirigami  # noqa: F401 - importing registers the QML types
import shim_plasmoid

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent.parent / "package"
FIXTURES = HERE.parent / "fixtures"

QML_SHIMS = {
    "org.kde.kirigami": ("kirigami", ["Icon", "FormLayout", "PasswordField"], ["Units", "Theme"]),
    "org.kde.plasma.components": ("components", ["Label", "ToolButton", "Button", "BusyIndicator", "ToolTip", "ScrollBar", "TextField"], []),
    "org.kde.plasma.core": ("misc", ["Action", "Types"], []),
    "org.kde.kcmutils": ("misc", ["SimpleKCM"], []),
    "org.kde.plasma.configuration": ("misc", ["ConfigModel", "ConfigCategory"], []),
    "org.kde.notification": ("misc", ["Notification"], []),
}

#: The account the stand-in for Deye Cloud knows. Nothing here is a real credential.
ACCOUNT = {"appId": "202600000000001", "appSecret": "secret-for-tests", "login": "tester@example.invalid", "password": "parolă-de-test"}
STATION = {"stationId": "61000001", "stationName": "Acasă"}
TOKEN = "token-for-tests"

problems = []
#: What the widget would have shown as desktop notifications.
notifications = []
#: The PlasmoidItem of an `applet` run, for reports made after it was built.
applet_root = []
# PySide destroys what a component created once the component itself is collected.
components = []


def on_message(kind, context, message):
    print(f"[qml] {message}", file=sys.stderr)

    if message.startswith("notification: "):
        notifications.append(message[len("notification: "):])

    # The store reports a failed refresh with a warning; a run that stages a failure expects it.
    if kind != QtMsgType.QtDebugMsg and kind != QtMsgType.QtInfoMsg and not message.startswith("Solar Now: the data could not be loaded"):
        problems.append(message)


def url(path):
    return QUrl.fromLocalFile(str(path))


def fixture(name):
    return (FIXTURES / name).read_text(encoding="utf-8")


def sha256(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class MockDeye(BaseHTTPRequestHandler):
    """Answers like the Deye Cloud OpenAPI does, from the fixtures, and keeps a log of what it was asked."""

    log = []
    #: offline answers nothing useful, rate answers 429, radiation-once fails the first forecast of
    #: Open-Meteo and answers the next ones, anything else behaves.
    behaviour = "ok"
    radiation_asked = 0

    def log_message(self, *arguments):
        pass

    def answer(self, status, body):
        payload = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json;charset=UTF-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        """Open-Meteo: the recorded radiation, moved so that its last day is tomorrow."""
        target = urlparse(self.path)

        if target.path != "/v1/forecast":
            self.answer(404, "{}")
            return

        MockDeye.radiation_asked += 1

        if MockDeye.behaviour == "radiation-once" and MockDeye.radiation_asked == 1:
            self.answer(503, "{}")
            MockDeye.log.append(f"GET {target.path} -> 503")
            return

        recorded = json.loads(fixture("openmeteo-radiation.json"))
        days = len(recorded["daily"]["time"])
        recorded["daily"]["time"] = [(date.today() + timedelta(days=1 - (days - 1 - index))).isoformat() for index in range(days)]
        self.answer(200, json.dumps(recorded))
        MockDeye.log.append(f"GET {target.path}?{target.query} -> radiation of {days} days")

    def do_POST(self):
        target = urlparse(self.path)
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        authorized = self.headers.get("Authorization") == f"bearer {TOKEN}"
        verdict = self.respond(target.path, parse_qs(target.query), body, authorized)
        seen = {key: ("<sha256>" if key == "password" else value) for key, value in body.items()}

        MockDeye.log.append(f"{target.path} authorized={authorized} body={seen} -> {verdict}")

    def respond(self, path, query, body, authorized):
        if MockDeye.behaviour == "rate":
            self.answer(429, "<html>Too Many Requests</html>")
            return "429"

        if MockDeye.behaviour == "offline":
            self.answer(502, "<html>Bad Gateway</html>")
            return "502"

        if path == "/v1.0/account/token":
            if query.get("appId") != [ACCOUNT["appId"]]:
                self.answer(200, fixture("error-invalid-appid.json"))
                return "invalid appId"

            if body.get("appSecret") != ACCOUNT["appSecret"] or body.get("email") != ACCOUNT["login"] or body.get("password") != sha256(ACCOUNT["password"]):
                # The wording of a refused password was not recorded from the real API.
                self.answer(200, json.dumps({"success": False, "code": "2101019", "msg": "wrong password"}))
                return "wrong password"

            self.answer(200, fixture("schema-token.json"))
            return "token issued"

        if not authorized:
            self.answer(200, fixture("error-token-missing.json"))
            return "token refused"

        if path == "/v1.0/station/list":
            self.answer(200, fixture("schema-station-list.json"))
            return "stations"

        if path == "/v1.0/station/latest" and body.get("stationId") in (int(STATION["stationId"]), int(STATION["stationId"]) + 1):
            self.answer(200, fixture("schema-station-latest.json"))
            return "latest"

        if path == "/v1.0/station/history":
            return self.history(body)

        if path == "/v1.0/station/alertList" and body.get("endTimestamp", 0) - body.get("startTimestamp", 0) <= 180 * 86400:
            self.answer(200, fixture("schema-station-alerts.json"))
            return f"alerts of {round((body['endTimestamp'] - body['startTimestamp']) / 86400)} days"

        if path == "/v1.0/station/device" and body.get("stationIds") == [int(STATION["stationId"])]:
            self.answer(200, fixture("schema-station-devices.json"))
            return "devices"

        if path == "/v1.0/device/latest":
            self.answer(200, fixture("schema-device-latest.json"))
            return f"measure points of {body.get('deviceList')}"

        self.answer(200, json.dumps({"success": False, "code": "2101006", "msg": "station not found"}))
        return "not found"

    def refuse(self, code, message):
        self.answer(200, json.dumps({"success": False, "code": code, "msg": message}))
        return f"refused: {message}"

    def history(self, body):
        """The fixtures, moved to the period asked for, with the limits the real API was seen to have on 2026-10-13."""
        granularity = body.get("granularity")
        start = str(body.get("startAt"))
        end = str(body.get("endAt"))
        today = date.today()

        if granularity == 1:
            if body.get("endAt") is None:
                return self.refuse("2101006", "invalid param")

            frames = json.loads(fixture("schema-station-frames.json"))
            asked = datetime.strptime(start, "%Y-%m-%d")
            shift = int(asked.timestamp()) - frames["stationDataItems"][0]["timeStamp"]

            for item in frames["stationDataItems"]:
                item["timeStamp"] += shift

            self.answer(200, json.dumps(frames if asked.date() <= today else dict(frames, stationDataItems=[])))
            return f"frames of {start}"

        if granularity == 2:
            first = date.fromisoformat(start)
            after = date.fromisoformat(end)

            if (after - first).days >= 31:
                return self.refuse("2101012", "should be within 31 days")

            if (after - first).days == 1:
                totals = json.loads(fixture("schema-station-day.json"))
                totals["stationDataItems"][-1].update(year=today.year, month=today.month, day=today.day)
                self.answer(200, json.dumps(totals))
                return f"totals of {start}..{end}"

            # The end of a range of days is not counted, and the days that are yet to come have no data.
            # Within the month of the fixture its own days are given; elsewhere they are reused in turn.
            month = json.loads(fixture("schema-station-month.json"))
            made = month["stationDataItems"]
            items = []

            for offset in range((after - first).days):
                day = first + timedelta(days=offset)

                if day <= today and (day.day <= len(made) or day.month != today.month):
                    items.append(dict(made[(day.day - 1) % len(made)], year=day.year, month=day.month, day=day.day))

            self.answer(200, json.dumps(dict(month, stationDataItems=items)))
            return f"days of {start}..{end}: {len(items)}"

        if granularity == 3:
            # The end of a range of months is counted.
            if (int(end[:4]) - int(start[:4])) * 12 + int(end[5:7]) - int(start[5:7]) + 1 > 12:
                return self.refuse("2101013", "should be within 12 month")

            year = json.loads(fixture("schema-station-year.json"))
            year["stationDataItems"] = [dict(item, year=int(start[:4])) for item in year["stationDataItems"] if item["year"] == 2026]
            self.answer(200, json.dumps(year))
            return f"months of {start}..{end}"

        self.answer(200, fixture("schema-station-years.json"))
        return f"years of {start}..{end}"


def start_mock(behaviour):
    MockDeye.behaviour = behaviour
    server = ThreadingHTTPServer(("127.0.0.1", 0), MockDeye)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    return f"http://127.0.0.1:{server.server_address[1]}"


def register_qml_shims():
    for module, (folder, types, singletons) in QML_SHIMS.items():
        for name in types:
            qmlRegisterType(url(HERE / "shims" / folder / f"{name}.qml"), module, 1, 0, name)

        for name in singletons:
            qmlRegisterSingletonType(url(HERE / "shims" / folder / f"{name}.qml"), module, 1, 0, name)


def config_defaults():
    """The defaults of contents/config/main.xml, as Plasma would hand them to the widget."""
    namespace = {"kcfg": "http://www.kde.org/standards/kcfg/1.0"}
    casts = {
        "String": lambda text: text or "",
        "Double": float,
        "Int": int,
        "Bool": lambda text: text == "true",
        "StringList": lambda text: [item for item in (text or "").split(",") if item],
    }
    entries = ElementTree.parse(PACKAGE / "contents/config/main.xml").getroot().iterfind(".//kcfg:entry", namespace)

    return {entry.get("name"): casts[entry.get("type")](entry.findtext("kcfg:default", namespaces=namespace)) for entry in entries}


def create(component, properties=None, context=None):
    components.append(component)
    item = component.createWithInitialProperties(properties, context) if properties else component.create(context)

    if item is None:
        for error in component.errors():
            problems.append(error.toString())
            print(f"[qml] {error.toString()}", file=sys.stderr)

        sys.exit(1)

    return item


def visual_tree(item):
    yield item

    for child in item.childItems():
        yield from visual_tree(child)


def has_property(item, name):
    return item.metaObject().indexOfProperty(name) >= 0


def motion(root):
    """Where the things that move are right now: the dots on the lines, and the parts of the icons that turn or slide."""
    dots = [item for item in visual_tree(root) if has_property(item, "along")]
    graphs = [item for item in visual_tree(root) if has_property(item, "iconClock")]

    return {
        "dots": [(round(dot.x(), 1), round(dot.y(), 1)) for dot in dots],
        "icons": [graph.property("iconClock") for graph in graphs],
    }


def build_stage(engine, arguments, configuration):
    # Either the answers made up after the schema, or the ones tools/capture.mjs recorded from a real station.
    def answer(made_up, recorded):
        return fixture(recorded if arguments.real else made_up)

    properties = {
        "latestJson": answer("schema-station-latest.json", "real-station-latest.json"),
        "dayJson": answer("schema-station-day.json", "real-station-day.json"),
        "latestOverridesJson": arguments.latest,
        "language": arguments.lang,
        "stationName": arguments.station_name,
        "currency": arguments.currency,
        "mode": arguments.mode,
        "problemText": arguments.problem_text,
        "loading": arguments.mode == "loading",
        "stale": arguments.stale,
        "animations": arguments.animations,
        "background": arguments.background,
        "backgroundTransparency": arguments.transparency,
        "powerUnit": arguments.unit,
        "fontScale": arguments.font_scale,
        "fontFamily": arguments.font,
        "showTotals": not arguments.no_totals,
        "lowBattery": arguments.low_battery,
        "invertGrid": arguments.invert_grid,
        "invertBattery": arguments.invert_battery,
        "tab": arguments.tab,
        "hiddenTabs": arguments.hide,
        "scale": arguments.scale,
        "archiveOutcome": arguments.archive,
        "framesJson": answer("schema-station-frames.json", "real-station-frames.json"),
        "monthJson": answer("schema-station-month.json", "real-station-month-1.json"),
        "yearJson": answer("schema-station-year.json", "real-station-year.json"),
        "yearsJson": answer("schema-station-years.json", "real-station-years.json"),
        "alertsJson": answer("schema-station-alerts.json", "real-station-alerts.json"),
        "deviceJson": answer("schema-device-latest.json", "real-device-latest.json"),
        "stationsJson": answer("schema-station-list.json", "real-station-list.json") if not arguments.real else fixture("schema-station-list.json"),
        "radiationJson": fixture("openmeteo-radiation.json"),
        "batteryCapacity": arguments.capacity,
        "showForecast": not arguments.no_forecast,
        "priceBuy": arguments.price_buy,
        "priceSell": arguments.price_sell,
        "pickerOpen": arguments.picker,
    }

    return create(QQmlComponent(engine, url(HERE / "Stage.qml")), properties)


def build_applet(engine, arguments, configuration):
    root = create(QQmlComponent(engine, url(PACKAGE / "contents/ui/main.qml")))
    applet_root.append(root)
    representation = root.property("compactRepresentation" if arguments.compact else "fullRepresentation")
    item = create(representation, context=representation.creationContext())

    # Keeps the PlasmoidItem, and the store inside it, alive for as long as the view.
    root.setParent(item)

    if not arguments.compact:
        item.setProperty("currentTab", arguments.tab)
        item.setProperty("historyScale", arguments.scale)

    def report():
        applet = shim_plasmoid.applet()
        settings = applet.property("configuration")

        print(f"applet: status={root.property('status')!r} tooltip={root.property('toolTipMainText')!r} / {root.property('toolTipSubText')!r}")
        print(f"applet: token kept={settings.value('accessToken')!r} expires in {round((settings.value('tokenExpiresAt') - __import__('time').time()) / 86400)} days; backgroundHints={applet.property('backgroundHints')}")
        # What Plasma shows where switch sizes are not set: the representation the widget prefers.
        preferred = root.property("preferredRepresentation")
        shown = "none" if preferred is None else "full" if getCppPointer(preferred) == getCppPointer(root.property("fullRepresentation")) else "compact"
        print(f"applet: shown={shown}")

    QTimer.singleShot(max(0, arguments.wait - 100), report)

    return item


def build_config(engine, arguments, configuration):
    model = create(QQmlComponent(engine, url(PACKAGE / "contents/config/config.qml")))
    categories = QQmlListReference(model, "categories")
    names = [categories.at(index).property("name") for index in range(categories.count())]
    category = categories.at(arguments.page)
    source = category.property("source")
    # As Plasma 6.7 does: every setting and its default go to every page, as initial properties.
    properties = {f"cfg_{key}": value for key, value in configuration.items()}
    properties.update({f"cfg_{key}Default": value for key, value in config_defaults().items()})
    page = create(QQmlComponent(engine, url(PACKAGE / "contents/ui" / source)), properties)

    print(f"config: pages={names} showing={category.property('name')!r} icon={category.property('icon')!r}")

    # Plasma writes each one a page lacks into the journal, as "Setting initial properties failed";
    # the Qt of the viewer says nothing. Apply writes them all back, so they must come back unchanged.
    for name, given in properties.items():
        if not has_property(page, name):
            problems.append(f"{source} does not have a property called {name}")
        elif page.property(name) != given:
            problems.append(f"{source} gives {name} back as {page.property(name)!r}, not {given!r}")

    # The widget renews the token on its own, also while the dialog is open: Apply must not bring the old one back.
    settings = shim_plasmoid.applet().property("configuration")
    renewed = "a-token-renewed-while-the-dialog-was-open"
    settings.insert("accessToken", renewed)
    QMetaObject.invokeMethod(page, "saveConfig")

    if page.property("cfg_accessToken") != renewed:
        problems.append(f"{source} would write back the token {page.property('cfg_accessToken')!r} over the renewed one")

    for problem in problems:
        print(f"[qml] {problem}", file=sys.stderr)

    model.setParent(page)

    return page


def record_frames(view, out, count, interval, done):
    """
    Saves `count` screenshots, one every `interval` milliseconds, as out-0000.png, out-0001.png…,
    and in out-times.txt the millisecond each was taken at, for an animation with the real timing.
    """
    stem = str(Path(out).with_suffix(""))
    clock = QElapsedTimer()
    times = []

    def grab():
        view.grabWindow().save(f"{stem}-{len(times):04d}.png")
        times.append(clock.elapsed())

        if len(times) < count:
            # Aimed at the next tick of the timeline, so that slow frames do not stretch it.
            QTimer.singleShot(max(0, interval * len(times) - clock.elapsed()), grab)
        else:
            Path(f"{stem}-times.txt").write_text("".join(f"{time}\n" for time in times))
            done()

    clock.start()
    grab()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["stage", "applet", "config"])
    parser.add_argument("out")
    parser.add_argument("--size", default="468x490")
    parser.add_argument("--wait", type=int, default=None, help="milliseconds before the screenshot")
    parser.add_argument("--light", action="store_true", help="light colour scheme")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", help="override a setting of the widget")
    parser.add_argument("--lang", default="ro")
    parser.add_argument("--mode", default="ready", choices=["ready", "setup", "noStation", "loading", "login", "credentials", "rate", "network", "api"])
    parser.add_argument("--problem-text", default="", help="stage: what the API said about the failure")
    parser.add_argument("--latest", default="{}", help="stage: JSON merged into the latest data of the fixture")
    parser.add_argument("--stale", action="store_true", help="stage: the station has been silent for long")
    parser.add_argument("--animations", default="off", choices=["full", "reduced", "off"], help="stage: off gives a still, repeatable picture")
    parser.add_argument("--background", default="black", choices=["black", "theme", "none"])
    parser.add_argument("--transparency", type=int, default=100, help="stage: percent of transparency of the transparent background")
    parser.add_argument("--form-factor", default="horizontal", choices=list(shim_plasmoid.FORM_FACTORS), help="applet: where the widget is: planar is the desktop")
    parser.add_argument("--unit", default="auto", choices=["auto", "w", "kw"])
    parser.add_argument("--font-scale", type=float, default=1.0)
    parser.add_argument("--font", default="")
    parser.add_argument("--no-totals", action="store_true")
    parser.add_argument("--low-battery", type=int, default=20)
    parser.add_argument("--invert-grid", action="store_true")
    parser.add_argument("--invert-battery", action="store_true")
    parser.add_argument("--tab", type=int, default=0, help="the tab on show: 0 flow, 1 day, 2 history, 3 balance, 4 alerts, 5 device")
    parser.add_argument("--hide", action="append", default=[], metavar="TAB", help="stage: a tab that is turned off")
    parser.add_argument("--scale", default="month", choices=["month", "year", "total"], help="what the history and the balance are shown by")
    parser.add_argument("--archive", default="ready", choices=["ready", "empty", "loading", "failed"], help="stage: how the answers of the tabs are staged")
    parser.add_argument("--price-buy", type=float, default=0, help="stage: what a kilowatt-hour from the grid costs")
    parser.add_argument("--price-sell", type=float, default=0, help="stage: what a kilowatt-hour sent to the grid brings")
    parser.add_argument("--picker", action="store_true", help="stage: the list of stations hangs open")
    parser.add_argument("--frames", type=int, default=0, metavar="COUNT", help="save COUNT screenshots instead of one, as OUT-0000.png…, with their times in OUT-times.txt")
    parser.add_argument("--frame-interval", type=int, default=66, metavar="MS", help="milliseconds between those screenshots")
    parser.add_argument("--station-name", default="Acasă", help="stage: the name of the station in the header")
    parser.add_argument("--currency", default="lei", help="stage: the currency of the prices")
    parser.add_argument("--real", action="store_true", help="stage: show the answers recorded by tools/capture.mjs instead of the made-up ones")
    parser.add_argument("--capacity", type=float, default=32.9, help="stage: capacity of the battery in kWh; 0 for one that is not known")
    parser.add_argument("--no-forecast", action="store_true", help="stage: the estimate of production is turned off")
    parser.add_argument("--pick-station", type=int, default=None, metavar="INDEX", help="applet: pick that station from the header and report what the settings hold")
    parser.add_argument("--expect-notifications", type=int, default=None, metavar="COUNT", help="applet: fail unless that many desktop notifications were sent")
    parser.add_argument("--compact", action="store_true", help="applet: show the panel representation")
    parser.add_argument("--page", type=int, default=0)
    parser.add_argument("--mock", action="store_true", help="applet, config: talk to a local stand-in for Deye Cloud, with a configured account")
    parser.add_argument("--mock-behaviour", default="ok", choices=["ok", "rate", "offline", "radiation-once"])
    parser.add_argument("--stale-token", action="store_true", help="applet: start with a token the API refuses, so that it has to be renewed")
    parser.add_argument("--forget-password", action="store_true", help="applet: no password kept, so a refused token cannot be renewed")
    parser.add_argument("--connect", default=None, metavar="PASSWORD", help="config: type PASSWORD on the account page and press Connect")
    parser.add_argument("--connected", action="store_true", help="config: the settings already hold a token and the second station of the account")
    parser.add_argument("--expect-stations", type=int, default=None, metavar="COUNT", help="config: fail unless the account page lists COUNT stations to pick from")
    parser.add_argument("--expect-motion", action="store_true", help="fail unless the dots on the lines and the icons are moving")
    arguments = parser.parse_args()

    if arguments.wait is None:
        arguments.wait = 2500 if arguments.what == "applet" or arguments.connect is not None or arguments.connected else 500

    qInstallMessageHandler(on_message)
    application = QGuiApplication(sys.argv[:1])
    register_qml_shims()

    configuration = config_defaults()

    if arguments.mock:
        address = start_mock(arguments.mock_behaviour)
        configuration.update(region="custom", customUrl=address, forecastHost=address)
        configuration.update({key: ACCOUNT[key] for key in ("appId", "appSecret", "login")})

        if arguments.what == "applet":
            configuration.update(STATION)
            configuration.update(passwordHash="" if arguments.forget_password else sha256(ACCOUNT["password"]))
            configuration.update(accessToken="a-token-the-api-refuses" if arguments.stale_token else TOKEN, tokenExpiresAt=4102444800.0)

        if arguments.connected:
            configuration.update(accessToken=TOKEN, tokenExpiresAt=4102444800.0, stationId="61000002", stationName="Atelier")

    for assignment in arguments.set:
        key, value = assignment.split("=", 1)
        default = configuration[key]
        configuration[key] = value.split(",") if isinstance(default, list) else value == "true" if isinstance(default, bool) else type(default)(value)

    for key, value in configuration.items():
        shim_plasmoid.applet().property("configuration").insert(key, value)

    width, height = (int(side) for side in arguments.size.split("x"))
    view = QQuickView()
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    view.setSource(url(HERE / "Host.qml"))
    view.resize(width, height)

    theme = view.engine().singletonInstance("org.kde.kirigami", "Theme")
    theme.setProperty("dark", not arguments.light)
    shim_plasmoid.form_factor[0] = shim_plasmoid.FORM_FACTORS[arguments.form_factor]

    background = configuration["background"] if arguments.what == "applet" else arguments.background
    view.rootObject().setProperty("framed", arguments.what == "config" or background == "theme")

    content = view.rootObject().findChild(QQuickItem, "content")
    item = {"stage": build_stage, "applet": build_applet, "config": build_config}[arguments.what](view.engine(), arguments, configuration)
    item.setParentItem(content)

    def fit():
        item.setWidth(content.width())
        item.setHeight(content.height())

    content.widthChanged.connect(fit)
    content.heightChanged.connect(fit)
    view.show()
    fit()

    def frames():
        record_frames(view, arguments.out, arguments.frames, arguments.frame_interval, shoot)

    def shoot():
        for line in MockDeye.log:
            print(f"mock: {line}")

        for line in notifications:
            print(f"notification: {line}")

        if arguments.expect_notifications is not None and len(notifications) != arguments.expect_notifications:
            problems.append(f"{len(notifications)} notifications were sent, not {arguments.expect_notifications}")

        if arguments.pick_station is not None:
            settings = shim_plasmoid.applet().property("configuration")
            print(f"station: settings now hold {settings.value('stationName')!r} ({settings.value('stationId')!r})")

        if arguments.expect_stations is not None:
            listed = item.property("stations")
            listed = listed.toVariant() if hasattr(listed, "toVariant") else listed
            names = [station["name"] for station in listed or []]
            print(f"stations: listed={names} picked={item.property('cfg_stationName')!r} ({item.property('cfg_stationId')!r})")

            if len(names) != arguments.expect_stations:
                problems.append(f"the account page lists {len(names)} stations, not {arguments.expect_stations}")

        saved = view.grabWindow().save(arguments.out)
        print(f"screenshot: {arguments.out} saved={saved} problems={len(problems)}")
        application.quit()

    def watch_motion():
        before = motion(item)

        def compare():
            after = motion(item)

            for what in ("dots", "icons"):
                moved = bool(before[what]) and before[what] != after[what]
                print(f"motion: {what} {'move' if moved else 'STAND STILL'}  {before[what][:3]} -> {after[what][:3]}")

                if not moved:
                    problems.append(f"the {what} do not move")

            shoot()

        QTimer.singleShot(800, compare)

    def connect():
        """Types the password on the account page, presses Connect and reports what the page would hand to the settings."""
        fields = [candidate for candidate in visual_tree(item) if candidate.objectName() == "passwordField"]
        buttons = [candidate for candidate in visual_tree(item) if candidate.objectName() == "connectButton"]

        if not fields or not buttons:
            problems.append("the account page has no password field or no Connect button")
            return shoot()

        fields[0].setProperty("text", arguments.connect)
        QMetaObject.invokeMethod(buttons[0], "clicked")

        def report():
            kept = {key: item.property(f"cfg_{key}") for key in ("accessToken", "tokenExpiresAt", "passwordHash", "stationId", "stationName")}
            kept["passwordHash"] = "the SHA-256 of the typed password" if kept["passwordHash"] == sha256(arguments.connect) else kept["passwordHash"]
            print(f"connect: message={item.property('message')!r} kept={kept} field now={fields[0].property('text')!r}")
            shoot()

        QTimer.singleShot(arguments.wait, report)

    if arguments.pick_station is not None:
        QTimer.singleShot(arguments.wait // 2, lambda: QMetaObject.invokeMethod(item, "pickStation", Q_ARG(int, arguments.pick_station)))

    if arguments.connect is not None:
        QTimer.singleShot(400, connect)
    else:
        QTimer.singleShot(arguments.wait, watch_motion if arguments.expect_motion else frames if arguments.frames else shoot)

    application.exec()

    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
