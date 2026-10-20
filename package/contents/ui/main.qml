pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/cache.mjs" as Cache
import "../code/flow.mjs" as Flow
import "../code/format.mjs" as Format
import "../code/i18n.mjs" as I18n
import "../code/inverter.mjs" as Inverter
import "../code/watch.mjs" as Watch

PlasmoidItem {
    id: root

    /** Follows the language of the Plasma interface unless a language is forced in the settings. */
    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    readonly property real fontScale: Plasmoid.configuration.fontScale / 100
    readonly property var colours: ({
        solar: Plasmoid.configuration.colorSolar,
        grid: Plasmoid.configuration.colorGrid,
        battery: Plasmoid.configuration.colorBattery,
        load: Plasmoid.configuration.colorLoad,
    })
    readonly property string warningColour: "#ff6b6b"
    /**
     * What flows where, from the last data that was loaded; null until there is any. While the widget
     * turns to another station this is still the flow of the old one, which is why `status` and not
     * this decides what is shown: whatever is on its way out can go on reading it until it is gone.
     */
    readonly property var flow: store.latest !== null
        ? Flow.buildFlow(store.latest, {
            idleBelow: Plasmoid.configuration.idleBelow,
            invertGrid: Plasmoid.configuration.invertGrid,
            invertBattery: Plasmoid.configuration.invertBattery,
        })
        : null
    /** ready, or why there is nothing to show; see `status` in FullRepresentation. */
    readonly property string status: {
        if (!store.hasAccount) {
            return "setup";
        }

        if (store.stationId === "") {
            return "noStation";
        }

        // Old numbers on screen must not hide that the widget has stopped and waits for the password.
        if (store.waitsForUser) {
            return store.problem;
        }

        return store.ready ? "ready" : store.problem !== "" ? store.problem : "loading";
    }
    /** When the station last reported, in seconds since 1970; 0 while unknown. */
    readonly property real updatedAt: store.ready && store.latest.updatedAt !== null ? store.latest.updatedAt : 0
    /** yyyy-MM-dd; worked out again with every refresh, so that a widget left running notices midnight. */
    readonly property string today: {
        store.fetchedAt;

        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }
    /**
     * The time, in milliseconds since 1970, moved on every minute: the data on screen has to look old
     * when no new data comes, whether the station is silent or the requests fail.
     */
    property real now: Date.now()
    /** The data on screen is older than a few refreshes take. */
    readonly property bool stale: updatedAt > 0 && now / 1000 - updatedAt > Math.max(15, Cache.refreshMinutes(Plasmoid.configuration.refreshMinutes) * 3) * 60

    // On the desktop the widget is always shown whole, and Plasma keeps it at least as big as that
    // needs; in a panel it is the icon that opens it. With switch sizes, a desktop widget smaller
    // than them, even one at its own minimum, which was the same size, turned into an oversized icon.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical ? compactRepresentation : fullRepresentation

    // The logo, as in Add Widgets: Plasma shows it in the notification of a removed widget.
    Plasmoid.icon: Qt.resolvedUrl("../icons/solar-now.png").toString()
    // On the desktop the widget draws its own background, unless it is asked to keep the one of the theme.
    Plasmoid.backgroundHints: Plasmoid.configuration.background === "theme" ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground
    toolTipMainText: Plasmoid.configuration.stationName !== "" ? Plasmoid.configuration.stationName : Plasmoid.title
    toolTipSubText: {
        if (status !== "ready") {
            const texts = { setup: "tooltip.setup", noStation: "state.noStation", loading: "state.loading", login: "state.login", credentials: "state.credentials", rate: "state.rate" };

            return I18n.t(language, texts[status] || "state.error");
        }

        const unit = Plasmoid.configuration.powerUnit;

        return [
            `${I18n.t(language, "node.solar")}: ${Format.power(flow.solar.power, unit, language)}`,
            `${I18n.t(language, "node.battery")}: ${Format.percent(flow.battery.soc)}`,
            `${I18n.t(language, "node.load")}: ${Format.power(flow.load.power, unit, language)}`,
        ].join("\n");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: I18n.t(root.language, "header.refresh")
            icon.name: "view-refresh"
            onTriggered: root.refreshAll()
        }
    ]

    /** Capacity of the battery in kWh: the one set by hand, or else the one the inverter reports; null while unknown. */
    readonly property var batteryCapacity: {
        if (Plasmoid.configuration.batteryCapacity > 0) {
            return Plasmoid.configuration.batteryCapacity;
        }

        const devices = archive.entries[archive.devicesKey()];

        return devices !== undefined && devices.data !== null ? Inverter.batteryCapacity(devices.data) : null;
    }

    /** What the notifications already told about, see code/watch.mjs. */
    property var watchState: Watch.STARTING
    readonly property bool notifying: Plasmoid.configuration.notifyBattery || Plasmoid.configuration.notifySilent || Plasmoid.configuration.notifyAlerts

    /** Looks at the data on hand for something worth a notification. */
    function watch(): void {
        if (!store.ready) {
            return;
        }

        const alerts = archive.entries[archive.alertsKey()];
        const result = Watch.watch(watchState, {
            soc: store.latest.soc,
            stale: stale,
            alerts: alerts !== undefined && alerts.status === "ready" ? alerts.data : null,
        }, {
            lowBattery: Plasmoid.configuration.lowBattery,
            notifyBattery: Plasmoid.configuration.notifyBattery,
            notifySilent: Plasmoid.configuration.notifySilent,
            notifyAlerts: Plasmoid.configuration.notifyAlerts,
        });
        const name = Plasmoid.configuration.stationName !== "" ? Plasmoid.configuration.stationName : Plasmoid.title;

        watchState = result.state;

        if (notifierLoader.item === null) {
            return;
        }

        result.events.forEach(event => {
            if (event.kind === "battery") {
                notifierLoader.item.send(I18n.t(language, "notify.batteryTitle", { station: name }), I18n.t(language, "notify.batteryText", { soc: Format.percent(event.soc) }));
            } else if (event.kind === "silent") {
                notifierLoader.item.send(I18n.t(language, "notify.silentTitle", { station: name }), I18n.t(language, "notify.silentText", { time: Qt.formatDateTime(new Date(updatedAt * 1000), "dd.MM HH:mm") }));
            } else {
                notifierLoader.item.send(I18n.t(language, "notify.alertTitle", { station: name }), event.name);
            }
        });
    }

    /** The refresh button: within a minute of the last answer, Deye has nothing newer to tell, unless asking failed. */
    function refreshAll(): void {
        if (store.problem !== "" || Cache.worthRefreshing(store.fetchedAt.getTime(), Date.now())) {
            store.refresh();
        }

        archive.refresh();
    }

    compactRepresentation: CompactRepresentation {
        flow: root.flow
        live: root.status === "ready"
        items: Plasmoid.configuration.compactItems
        colours: root.colours
        warningColour: root.warningColour
        powerUnit: Plasmoid.configuration.powerUnit
        language: root.language
        lowBattery: Plasmoid.configuration.lowBattery

        /** Whether the popup was open when the press began: the press itself closes it, as it takes the focus away. */
        property bool wasExpanded: false

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded
    }

    fullRepresentation: FullRepresentation {
        flow: root.flow
        day: store.day
        status: root.status
        problemText: store.problemText
        loading: store.loading
        stationName: Plasmoid.configuration.stationName !== "" ? Plasmoid.configuration.stationName : Plasmoid.title
        updatedAt: root.updatedAt
        stale: root.stale
        now: root.now
        language: root.language
        fontScale: root.fontScale
        fontFamily: Plasmoid.configuration.fontFamily
        animations: Plasmoid.configuration.animations
        background: Plasmoid.configuration.background
        backgroundTransparency: Plasmoid.configuration.backgroundTransparency
        powerUnit: Plasmoid.configuration.powerUnit
        colours: root.colours
        showTotals: Plasmoid.configuration.showTotals
        lowBattery: Plasmoid.configuration.lowBattery
        invertGrid: Plasmoid.configuration.invertGrid
        invertBattery: Plasmoid.configuration.invertBattery
        archive: archive
        today: root.today
        hiddenTabs: Plasmoid.configuration.hiddenTabs
        prices: ({ buy: Plasmoid.configuration.priceBuy, sell: Plasmoid.configuration.priceSell })
        currency: Plasmoid.configuration.currency
        stationId: Plasmoid.configuration.stationId
        batteryCapacity: root.batteryCapacity
        batteryReserve: Plasmoid.configuration.batteryReserve
        showForecast: Plasmoid.configuration.showForecast

        onRefreshRequested: root.refreshAll()
        onSettingsRequested: Plasmoid.internalAction("configure").trigger()
        onStationPicked: (id, name) => {
            Plasmoid.configuration.stationId = id;
            Plasmoid.configuration.stationName = name;
        }
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: true

        onTriggered: {
            const time = Date.now();

            // A minute that took much longer means the computer slept: what is on screen is old, ask at once.
            if (time - root.now > 3 * interval) {
                store.refresh();
            }

            root.now = time;
        }
    }

    ArchiveStore {
        id: archive

        source: store
        forecastHost: Plasmoid.configuration.forecastHost

        // New alerts are among the answers that arrive here.
        onEntriesChanged: Qt.callLater(root.watch)
    }

    // On its own, so that a system without the notification module still gets the widget.
    Loader {
        id: notifierLoader

        active: root.notifying
        source: "Notifier.qml"

        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("Solar Now: notifications are not available on this system");
            }
        }
    }

    Connections {
        target: store

        // What was told about one station says nothing about another: its alerts and its battery start afresh.
        function onRequestKeyChanged(): void {
            root.watchState = Watch.STARTING;
        }

        // Every refresh is looked at, and is a chance to ask whether the station raised an alert.
        function onFetchedAtChanged(): void {
            if (Plasmoid.configuration.notifyAlerts) {
                archive.loadAlerts();
            }

            // The capacity of the battery does not change: the inverter is asked for it once, and again only after a failure.
            const devices = archive.entries[archive.devicesKey()];

            if (Plasmoid.configuration.batteryCapacity === 0 && (devices === undefined || devices.status === "failed")) {
                archive.loadDevices();
            }

            Qt.callLater(root.watch);
        }
    }

    SolarStore {
        id: store

        region: Plasmoid.configuration.region
        customUrl: Plasmoid.configuration.customUrl
        appId: Plasmoid.configuration.appId
        appSecret: Plasmoid.configuration.appSecret
        login: Plasmoid.configuration.login
        passwordHash: Plasmoid.configuration.passwordHash
        companyId: Plasmoid.configuration.companyId
        accessToken: Plasmoid.configuration.accessToken
        tokenExpiresAt: Plasmoid.configuration.tokenExpiresAt
        stationId: Plasmoid.configuration.stationId
        refreshMinutes: Cache.refreshMinutes(Plasmoid.configuration.refreshMinutes)
        totalsEnabled: Plasmoid.configuration.showTotals

        onTokenIssued: (accessToken, expiresAt) => {
            Plasmoid.configuration.accessToken = accessToken;
            Plasmoid.configuration.tokenExpiresAt = expiresAt;
        }
    }
}
