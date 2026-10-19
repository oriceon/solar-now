pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/chart.mjs" as Chart
import "../../code/flow.mjs" as Flow
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/period.mjs" as Period
import "../charts" as Charts
import "../components" as Components

/** The powers of the station through a day, as a curve; the figures above it are those under the pointer, or the last ones. */
ColumnLayout {
    id: tab

    /** ArchiveStore, or a stand-in with its answers. */
    required property QtObject archive
    /** yyyy-MM-dd */
    required property string today
    /** The day on show, yyyy-MM-dd. */
    required property string day
    required property string language
    required property var typography
    required property var scheme
    required property var colours
    required property string powerUnit
    required property bool invertGrid
    required property bool invertBattery

    readonly property string key: archive.framesKey(day)
    readonly property var entry: archive.entries[key] !== undefined ? archive.entries[key] : null
    readonly property var frames: entry !== null && entry.data !== null ? entry.data : []
    /** loading, failed, empty or ready */
    readonly property string status: frames.length > 0 ? "ready" : entry === null || entry.status === "loading" ? "loading" : entry.status === "failed" ? "failed" : "empty"
    /** The frame the figures are read from: the one under the pointer, or the last of the day. */
    readonly property var shown: frames.length === 0 ? null : frames[chart.hovered >= 0 && chart.hovered < frames.length ? chart.hovered : frames.length - 1]
    readonly property var lineColours: ({ generation: colours.solar, consumption: colours.load, grid: colours.grid, battery: colours.battery, soc: scheme.text })
    readonly property var readout: [
        { label: I18n.t(language, "series.generation"), colour: lineColours.generation, value: shown === null ? "" : Format.power(shown.generation, powerUnit, language) },
        { label: I18n.t(language, "series.consumption"), colour: lineColours.consumption, value: shown === null ? "" : Format.power(shown.consumption, powerUnit, language) },
        { label: I18n.t(language, "series.grid"), colour: lineColours.grid, value: shown === null ? "" : Format.power(Flow.gridFlow(shown, invertGrid), powerUnit, language) },
        { label: I18n.t(language, "series.battery"), colour: lineColours.battery, value: shown === null ? "" : Format.power(Flow.batteryFlow(shown, invertBattery), powerUnit, language) },
        { label: I18n.t(language, "series.soc"), colour: lineColours.soc, value: shown === null ? "" : Format.percent(shown.soc) },
    ]

    /** "Vârf de producție 4,12 kW la 13:05 · Vârf de consum 3,40 kW la 19:20", with whichever of the two there was. */
    readonly property string peaksText: {
        const peaks = Chart.dayPeaks(frames);
        const parts = [];

        [["generation", "day.peakGeneration"], ["consumption", "day.peakConsumption"]].forEach(pair => {
            if (peaks[pair[0]] !== null) {
                parts.push(I18n.t(language, pair[1], {
                    value: Format.power(peaks[pair[0]].value, powerUnit, language),
                    time: Qt.formatTime(new Date(peaks[pair[0]].time * 1000), "HH:mm"),
                }));
            }
        });

        return parts.join(" · ");
    }

    signal dayPicked(string day)

    function load(): void {
        archive.loadFrames(day, today);
    }

    spacing: Kirigami.Units.smallSpacing

    Components.PeriodBar {
        Layout.fillWidth: true
        label: I18n.dayLabel(tab.language, tab.day, tab.today) + (tab.shown !== null ? ` · ${Qt.formatTime(new Date(tab.shown.time * 1000), "HH:mm")}` : "")
        canGoBack: true
        canGoForward: Period.canGoForward("day", tab.day, tab.today)
        typography: tab.typography
        scheme: tab.scheme

        onStepped: steps => tab.dayPicked(Period.shiftDay(tab.day, steps))
    }

    Components.Legend {
        Layout.fillWidth: true
        items: tab.readout
        columns: width >= Kirigami.Units.gridUnit * 22 ? 5 : 3
        typography: tab.typography
        scheme: tab.scheme
    }

    Components.Label {
        Layout.fillWidth: true
        visible: text !== ""
        typography: tab.typography
        relativeSize: 0.82
        wrapMode: Text.WordWrap
        color: tab.scheme.secondary
        text: tab.peaksText
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Charts.LineChart {
            id: chart

            anchors.fill: parent
            visible: tab.status === "ready"
            series: Chart.daySeries(tab.frames, { invertGrid: tab.invertGrid, invertBattery: tab.invertBattery })
            frames: tab.frames
            day: tab.day
            colours: tab.lineColours
            typography: tab.typography
            scheme: tab.scheme
            decimalMark: tab.language === "ro" ? "," : "."
        }

        Components.Notice {
            anchors.fill: parent
            visible: tab.status !== "ready"
            typography: tab.typography
            scheme: tab.scheme
            text: I18n.t(tab.language, `tabstate.${tab.status}`)
        }
    }

    Components.Label {
        Layout.fillWidth: true
        typography: tab.typography
        relativeSize: 0.75
        wrapMode: Text.WordWrap
        color: tab.scheme.secondary
        text: I18n.t(tab.language, "day.signs")
    }

    Connections {
        target: tab.archive

        function onStale(): void {
            tab.load();
        }
    }

    // Later, not now: the key changes while the answer bound to it is being worked out, and loading replaces the answers.
    onKeyChanged: Qt.callLater(load)
    Component.onCompleted: load()
}
