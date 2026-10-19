pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../code/colours.mjs" as Colours
import "../code/forecast.mjs" as Forecast
import "../code/i18n.mjs" as I18n
import "../code/period.mjs" as Period
import "components" as Components
import "tabs" as Tabs

Item {
    id: full

    /** buildFlow() of code/flow.mjs. Only read while `status` is ready. */
    required property var flow
    /** parseDay() of code/deye.mjs for today, null while unknown. */
    required property var day
    /**
     * ready, or why there is nothing to show: setup (no account yet), noStation, loading,
     * login, credentials, rate, network, api, malformed.
     */
    required property string status
    /** What the API said about a failure, when it said anything. */
    required property string problemText
    required property bool loading
    required property string stationName
    /** When the station last reported, in seconds since 1970; 0 while unknown. */
    required property real updatedAt
    /** True when that was long ago: the numbers on screen may no longer hold. */
    required property bool stale
    /** The time, in milliseconds since 1970, moved on every minute. */
    required property real now
    required property string language
    /** Size of the text relative to the font of the Plasma theme. */
    required property real fontScale
    /** Empty for the font of the Plasma theme. */
    required property string fontFamily
    /** full | reduced | off */
    required property string animations
    /** black | theme | none */
    required property string background
    /** auto | w | kw */
    required property string powerUnit
    /** Colour of every source and consumer, as text: `{ solar, grid, battery, load }`. */
    required property var colours
    required property bool showTotals
    /** Percent under which the battery is drawn as low. */
    required property real lowBattery
    required property bool invertGrid
    required property bool invertBattery
    /** ArchiveStore, or a stand-in with its answers: what the tabs beside the flow show. */
    required property QtObject archive
    /** yyyy-MM-dd */
    required property string today
    /** Ids of the tabs the user turned off. */
    required property var hiddenTabs
    /** `{ buy, sell }`: what a kilowatt-hour costs and brings; both 0 hides the money. */
    required property var prices
    required property string currency
    /** Id of the station on show. */
    required property string stationId
    /** Capacity of the battery in kWh, null while unknown. */
    required property var batteryCapacity
    /** Percent under which the inverter no longer draws from the battery. */
    required property real batteryReserve
    required property bool showForecast

    /** True while the list of stations hangs open under the name of the station. */
    property bool pickerOpen: false

    /** Index into `tabIds`. */
    property int currentTab: 0
    /** The day the curve is shown for; empty for today. */
    property string pickedDay: ""
    /** What the history and the balance are shown by: month, year or total. */
    property string historyScale: "month"
    /** The period they are shown for; empty for the one today is in. */
    property string pickedAnchor: ""

    readonly property var typography: ({
        family: fontFamily !== "" ? fontFamily : Kirigami.Theme.defaultFont.family,
        size: Kirigami.Theme.defaultFont.pointSize * fontScale,
    })
    /** On its own black background the widget brings its own colours; otherwise it follows the Plasma theme. */
    readonly property bool ownColours: background === "black"
    readonly property var scheme: ownColours
        ? ({ text: "#f4f6fa", secondary: "#8d95a8", card: "#0c0f15", edge: "#262b36", track: "#3b4252", colourfulText: true })
        : ({
            // The bright colours of the nodes read well as text on a dark theme, not on a light one.
            colourfulText: Colours.isDark(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b),
            text: String(Kirigami.Theme.textColor),
            secondary: String(Kirigami.Theme.disabledTextColor),
            card: String(Qt.alpha(Kirigami.Theme.textColor, 0.06)),
            edge: String(Qt.alpha(Kirigami.Theme.textColor, 0.2)),
            track: String(Kirigami.Theme.disabledTextColor),
        })
    readonly property string warningColour: "#ff6b6b"
    /** Bigger text needs a bigger widget. */
    readonly property real roomFactor: Math.max(1, fontScale)
    /** A day or more old: the hour alone would pass for today's. */
    readonly property string updatedText: {
        if (updatedAt <= 0) {
            return "";
        }

        const moment = new Date(updatedAt * 1000);
        const old = now / 1000 - updatedAt > 20 * 3600;

        return I18n.t(language, stale ? "header.stale" : "header.updated", { time: Qt.formatDateTime(moment, old ? "dd.MM HH:mm" : "HH:mm") });
    }
    readonly property var tabOrder: ["flow", "day", "history", "balance", "alerts", "device"]
    readonly property var tabIds: {
        const shown = tabOrder.filter(id => !isHidden(id));

        return shown.length > 0 ? shown : [tabOrder[0]];
    }
    readonly property string tabId: tabIds[Math.min(currentTab, tabIds.length - 1)]
    /** The day the curve is shown for, yyyy-MM-dd. */
    readonly property string dayShown: pickedDay !== "" ? pickedDay : today
    readonly property string historyAnchor: pickedAnchor !== "" ? pickedAnchor : Period.anchorFor(historyScale, today)
    /** What the status view says and which button it offers, by status. */
    readonly property var statusViews: ({
        setup: { title: "state.setupTitle", text: "state.setupText", action: "settings" },
        noStation: { title: "", text: "state.noStation", action: "settings" },
        loading: { title: "", text: "state.loading", action: "" },
        login: { title: "", text: "state.login", action: "settings" },
        credentials: { title: "", text: "state.credentials", action: "settings" },
        rate: { title: "", text: "state.rate", action: "retry" },
    })
    readonly property var statusView: statusViews[status] || { title: "", text: "state.error", action: "retry" }

    /** parseStations() of code/deye.mjs: the stations of the account, empty until known. */
    readonly property var stations: {
        const entry = archive.entries[archive.stationsKey()];

        return entry !== undefined && entry.data !== null ? entry.data : [];
    }
    /** With a single station there is nothing to switch to. */
    readonly property bool canSwitchStation: status === "ready" && stations.length > 1
    /** Where the station on show is, as the account lists it; null until known. */
    readonly property var place: {
        const found = stations.filter(station => station.id === stationId && station.latitude !== null && station.longitude !== null);

        return found.length > 0 ? found[0] : null;
    }
    /** What today and tomorrow are expected to produce: `{ today, tomorrow }`, null when there is nothing to go by. */
    readonly property var forecast: {
        const entry = archive.entries[archive.forecastKey(today)];

        if (!showForecast || entry === undefined || entry.data === null) {
            return null;
        }

        return {
            today: Forecast.expectedProduction(entry.data.days, entry.data.radiation, today),
            tomorrow: Forecast.expectedProduction(entry.data.days, entry.data.radiation, Period.shiftDay(today, 1)),
        };
    }

    /** The estimate needs to know where the station is. */
    function loadForecast(): void {
        if (showForecast && place !== null) {
            archive.loadForecast(today, place.latitude, place.longitude);
        }
    }

    signal refreshRequested()
    signal settingsRequested()
    /** Another station of the account was picked from the header. */
    signal stationPicked(string id, string name)

    function pickStation(index: int): void {
        pickerOpen = false;

        if (stations[index].id !== stationId) {
            stationPicked(stations[index].id, stations[index].name);
        }
    }

    function isHidden(id: string): bool {
        for (let index = 0; index < hiddenTabs.length; index++) {
            if (hiddenTabs[index] === id) {
                return true;
            }
        }

        return false;
    }

    /** Another kind of period starts at the one today is in. */
    function pickScale(scale: string): void {
        historyScale = scale;
        pickedAnchor = "";
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18 * roomFactor
    Layout.minimumHeight: Kirigami.Units.gridUnit * 20 * roomFactor
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24 * roomFactor
    Layout.preferredHeight: Kirigami.Units.gridUnit * 25 * roomFactor

    Rectangle {
        anchors.fill: parent
        visible: full.ownColours
        radius: Kirigami.Units.cornerRadius * 2
        color: "#000000"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: full.background === "theme" ? 0 : Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Components.Label {
                id: stationLabel

                Layout.fillWidth: true
                typography: full.typography
                relativeSize: 1.2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                color: full.scheme.text
                text: full.stationName + (full.canSwitchStation ? " ▾" : "")

                MouseArea {
                    width: Math.min(parent.width, parent.implicitWidth)
                    height: parent.height
                    enabled: full.canSwitchStation
                    cursorShape: Qt.PointingHandCursor

                    onClicked: full.pickerOpen = !full.pickerOpen
                }
            }

            Components.Label {
                typography: full.typography
                relativeSize: 0.85
                visible: full.status === "ready" && text !== ""
                color: full.stale ? full.warningColour : full.scheme.secondary
                text: full.updatedText
            }

            Components.RefreshButton {
                visible: full.status !== "setup" && full.status !== "noStation"
                colour: full.scheme.text
                busy: full.loading
                label: I18n.t(full.language, "header.refresh")

                onClicked: full.refreshRequested()
            }
        }

        Components.TabStrip {
            Layout.fillWidth: true
            visible: full.status === "ready" && full.tabIds.length > 1
            labels: full.tabIds.map(id => I18n.t(full.language, `tab.${id}`))
            current: Math.min(full.currentTab, full.tabIds.length - 1)
            typography: full.typography
            scheme: full.scheme

            onPicked: index => full.currentTab = index
        }

        // Only the tab in view exists, so the others cost nothing and ask the API for nothing.
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: full.status !== "ready"
                ? statusPane
                : ({ flow: flowTab, day: dayTab, history: historyTab, balance: balanceTab, alerts: alertsTab, device: deviceTab })[full.tabId]
        }
    }

    // A click anywhere else closes the list of stations.
    MouseArea {
        anchors.fill: parent
        visible: full.pickerOpen

        onClicked: full.pickerOpen = false
    }

    Rectangle {
        visible: full.pickerOpen && full.canSwitchStation
        x: Kirigami.Units.largeSpacing
        y: Kirigami.Units.largeSpacing + stationLabel.height + Kirigami.Units.smallSpacing
        width: Math.min(full.width - 2 * x, Kirigami.Units.gridUnit * 16)
        height: stationList.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        // Opaque whatever the background of the widget is: a list over a chart has to read.
        color: full.ownColours ? "#12151c" : Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: full.scheme.edge

        Column {
            id: stationList

            x: Kirigami.Units.smallSpacing
            y: Kirigami.Units.smallSpacing
            width: parent.width - 2 * x

            Repeater {
                model: full.stations

                delegate: Rectangle {
                    id: choice

                    required property var modelData
                    required property int index

                    readonly property bool current: modelData.id === full.stationId

                    width: stationList.width
                    height: choiceName.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: choiceTouch.containsMouse ? Qt.alpha(full.scheme.text, 0.1) : "transparent"

                    Components.Label {
                        id: choiceName

                        anchors.verticalCenter: parent.verticalCenter
                        x: Kirigami.Units.smallSpacing * 2
                        width: parent.width - 2 * x
                        typography: full.typography
                        font.weight: choice.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        color: choice.current ? full.scheme.text : full.scheme.secondary
                        text: (choice.current ? "✓ " : "") + choice.modelData.name
                    }

                    MouseArea {
                        id: choiceTouch

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: full.pickStation(choice.index)
                    }
                }
            }
        }
    }

    Connections {
        target: full.archive

        function onStale(): void {
            full.archive.loadStations();
            full.loadForecast();
        }
    }

    onPlaceChanged: Qt.callLater(full.loadForecast)
    onShowForecastChanged: Qt.callLater(full.loadForecast)
    Component.onCompleted: Qt.callLater(full.archive.loadStations)

    Component {
        id: flowTab

        Tabs.FlowTab {
            flow: full.flow
            day: full.day
            showTotals: full.showTotals
            language: full.language
            typography: full.typography
            scheme: full.scheme
            colours: full.colours
            warningColour: full.warningColour
            animations: full.animations
            powerUnit: full.powerUnit
            lowBattery: full.lowBattery
            roomFactor: full.roomFactor
            batteryCapacity: full.batteryCapacity
            batteryReserve: full.batteryReserve
            forecast: full.forecast
        }
    }

    Component {
        id: dayTab

        Tabs.DayTab {
            archive: full.archive
            today: full.today
            day: full.dayShown
            language: full.language
            typography: full.typography
            scheme: full.scheme
            colours: full.colours
            powerUnit: full.powerUnit
            invertGrid: full.invertGrid
            invertBattery: full.invertBattery

            onDayPicked: day => full.pickedDay = day === full.today ? "" : day
        }
    }

    Component {
        id: historyTab

        Tabs.HistoryTab {
            archive: full.archive
            today: full.today
            scale: full.historyScale
            anchor: full.historyAnchor
            prices: full.prices
            currency: full.currency
            language: full.language
            typography: full.typography
            scheme: full.scheme
            colours: full.colours

            onScalePicked: scale => full.pickScale(scale)
            onAnchorPicked: anchor => full.pickedAnchor = anchor
        }
    }

    Component {
        id: balanceTab

        Tabs.BalanceTab {
            archive: full.archive
            today: full.today
            scale: full.historyScale
            anchor: full.historyAnchor
            prices: full.prices
            currency: full.currency
            language: full.language
            typography: full.typography
            scheme: full.scheme
            colours: full.colours

            onScalePicked: scale => full.pickScale(scale)
            onAnchorPicked: anchor => full.pickedAnchor = anchor
        }
    }

    Component {
        id: alertsTab

        Tabs.AlertsTab {
            archive: full.archive
            language: full.language
            typography: full.typography
            scheme: full.scheme
            warningColour: full.warningColour
        }
    }

    Component {
        id: deviceTab

        Tabs.DeviceTab {
            archive: full.archive
            language: full.language
            typography: full.typography
            scheme: full.scheme
        }
    }

    Component {
        id: statusPane

        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 20)
                spacing: Kirigami.Units.largeSpacing

                Components.Label {
                    width: parent.width
                    visible: text !== ""
                    typography: full.typography
                    relativeSize: 1.2
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: full.scheme.text
                    text: full.statusView.title !== "" ? I18n.t(full.language, full.statusView.title) : ""
                }

                Components.Label {
                    width: parent.width
                    typography: full.typography
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: full.statusView.title !== "" ? full.scheme.secondary : full.scheme.text
                    text: I18n.t(full.language, full.statusView.text)
                }

                // What the API itself said, for a failure the widget has no words of its own for.
                Components.Label {
                    width: parent.width
                    visible: full.problemText !== "" && full.statusView.text === "state.error"
                    typography: full.typography
                    relativeSize: 0.85
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: full.scheme.secondary
                    text: full.problemText
                }

                Components.PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: full.statusView.action !== ""
                    typography: full.typography
                    colour: full.scheme.text
                    text: I18n.t(full.language, full.statusView.action === "settings" ? "state.openSettings" : "state.retry")

                    onClicked: {
                        if (full.statusView.action === "settings") {
                            full.settingsRequested();
                        } else {
                            full.refreshRequested();
                        }
                    }
                }
            }
        }
    }
}
