import QtQuick

import "../../package/contents/code/deye.mjs" as Deye
import "../../package/contents/code/flow.mjs" as Flow
import "../../package/contents/ui" as Ui

// Renders the full representation from API answers kept as fixtures, without the network.
Item {
    id: stage

    /** Answer of /station/latest. */
    property string latestJson
    /** Answer of /station/history for a day. */
    property string dayJson
    /** The day of `dayJson` the totals are read for. */
    property string dayDate: "2026-10-13"
    /** Fields that replace those of the latest data, to stage a moment the fixture does not have. */
    property string latestOverridesJson: "{}"
    property string language: "ro"
    /** The name of the station in the header. */
    property string stationName: "Acasă"
    /** The currency the prices are given in. */
    property string currency: "lei"
    /** ready, or one of the states without data; see `status` in FullRepresentation. */
    property string mode: "ready"
    property string problemText: ""
    property bool loading: false
    property bool stale: false
    property string animations: "off"
    property string background: "black"
    property string powerUnit: "auto"
    property real fontScale: 1
    property string fontFamily: ""
    property bool showTotals: true
    property int idleBelow: 1
    property int lowBattery: 20
    property bool invertGrid: false
    property bool invertBattery: false
    property var colours: ({ solar: "#ffc53d", grid: "#8b9dff", battery: "#3ddc97", load: "#4cc9f0" })
    /** Index of the tab on show: 0 flow, 1 day, 2 history, 3 balance, 4 alerts, 5 device. */
    property int tab: 0
    property var hiddenTabs: []
    /** month, year or total */
    property string scale: "month"
    /** The day the stage pretends it is. */
    property string today: "2026-10-13"
    /** Answers of the history, alert and device endpoints. */
    property alias framesJson: archive.framesJson
    property alias monthJson: archive.monthJson
    property alias yearJson: archive.yearJson
    property alias yearsJson: archive.yearsJson
    property alias alertsJson: archive.alertsJson
    property alias deviceJson: archive.deviceJson
    /** Answer of /station/list; a single station hides the switch in the header. */
    property alias stationsJson: archive.stationsJson
    property real priceBuy: 0
    property real priceSell: 0
    /** True to stage the list of stations hanging open. */
    property bool pickerOpen: false
    property alias radiationJson: archive.radiationJson
    /** Capacity of the battery in kWh; 0 stages one that is not known. */
    property real batteryCapacity: 32.9
    property bool showForecast: true
    /** How the answers of the archive are staged: ready, empty, loading or failed. */
    property alias archiveOutcome: archive.outcome

    readonly property var latest: Object.assign(Deye.parseLatest(Deye.readResponse(latestJson).data), JSON.parse(latestOverridesJson))

    FixtureArchive {
        id: archive
    }

    Ui.FullRepresentation {
        anchors.fill: parent
        archive: archive
        today: stage.today
        hiddenTabs: stage.hiddenTabs
        currentTab: stage.tab
        historyScale: stage.scale
        prices: ({ buy: stage.priceBuy, sell: stage.priceSell })
        currency: stage.currency
        stationId: "61000001"
        pickerOpen: stage.pickerOpen
        batteryCapacity: stage.batteryCapacity > 0 ? stage.batteryCapacity : null
        batteryReserve: 20
        showForecast: stage.showForecast
        invertGrid: stage.invertGrid
        invertBattery: stage.invertBattery
        flow: Flow.buildFlow(stage.latest, { idleBelow: stage.idleBelow, invertGrid: stage.invertGrid, invertBattery: stage.invertBattery })
        day: Deye.parseDay(Deye.readResponse(stage.dayJson).data, stage.dayDate)
        status: stage.mode
        problemText: stage.problemText
        loading: stage.loading
        stationName: stage.stationName
        updatedAt: stage.latest.updatedAt
        stale: stage.stale
        // A few minutes after the station last reported.
        now: (stage.latest.updatedAt + 300) * 1000
        language: stage.language
        fontScale: stage.fontScale
        fontFamily: stage.fontFamily
        animations: stage.animations
        background: stage.background
        powerUnit: stage.powerUnit
        colours: stage.colours
        showTotals: stage.showTotals
        lowBattery: stage.lowBattery
    }
}
