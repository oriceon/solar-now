pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/chart.mjs" as Chart
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/period.mjs" as Period
import "../charts" as Charts
import "../components" as Components

/**
 * The energy of a month by days, of a year by months, or of all the years: what came in stacked
 * above zero, what went out below it. The figures are those of the bar under the pointer, or of the whole period.
 */
ColumnLayout {
    id: tab

    /** ArchiveStore, or a stand-in with its answers. */
    required property QtObject archive
    /** yyyy-MM-dd */
    required property string today
    /** month, year or total */
    required property string scale
    /** The period on show: yyyy-MM for a month, yyyy otherwise. */
    required property string anchor
    required property string language
    required property var typography
    required property var scheme
    required property var colours
    /** `{ buy, sell }`: what a kilowatt-hour costs and brings; both 0 hides the money. */
    required property var prices
    required property string currency

    readonly property var scaleIds: ["month", "year", "total"]
    readonly property var sources: ["generation", "discharge", "purchase"]
    readonly property var uses: ["consumption", "charge", "feedIn"]
    readonly property var quantityColours: ({
        generation: colours.solar,
        discharge: colours.battery,
        purchase: colours.grid,
        consumption: colours.load,
        charge: colours.battery,
        feedIn: colours.grid,
    })
    readonly property string key: archive.historyKey(scale, anchor)
    readonly property var entry: archive.entries[key] !== undefined ? archive.entries[key] : null
    readonly property var rows: entry !== null && entry.data !== null ? entry.data : []
    /** loading, failed, empty or ready */
    readonly property string status: rows.length > 0 ? "ready" : entry === null || entry.status === "loading" ? "loading" : entry.status === "failed" ? "failed" : "empty"
    readonly property bool pointed: chart.hovered >= 0 && chart.hovered < rows.length
    /** The figures on show: those of the bar under the pointer, or of the whole period. */
    readonly property var figures: pointed ? rows[chart.hovered] : Chart.totals(rows)
    readonly property var legend: sources.map(name => tab.legendEntry(name, "↑")).concat(uses.map(name => tab.legendEntry(name, "↓")))

    signal scalePicked(string scale)
    signal anchorPicked(string anchor)

    function legendEntry(name: string, arrow: string): var {
        return {
            label: `${arrow} ${I18n.t(language, `energy.${name}`)}`,
            colour: quantityColours[name],
            value: status === "ready" ? Format.energy(figures[name], language) : "",
        };
    }

    function load(): void {
        archive.loadHistory(scale, anchor, Period.anchorFor(scale, today));
    }

    spacing: Kirigami.Units.smallSpacing

    Components.PeriodBar {
        Layout.fillWidth: true
        label: (tab.pointed ? `${I18n.barLabel(tab.language, tab.scale, tab.rows[chart.hovered].key)} · ` : "") + I18n.periodLabel(tab.language, tab.scale, tab.anchor)
        canGoBack: tab.scale !== "total"
        canGoForward: Period.canGoForward(tab.scale, tab.anchor, tab.today)
        scales: tab.scaleIds.map(id => I18n.t(tab.language, `scale.${id}`))
        currentScale: tab.scaleIds.indexOf(tab.scale)
        typography: tab.typography
        scheme: tab.scheme

        onStepped: steps => tab.anchorPicked(Period.shiftAnchor(tab.scale, tab.anchor, steps))
        onScalePicked: index => tab.scalePicked(tab.scaleIds[index])
    }

    Components.Legend {
        Layout.fillWidth: true
        items: tab.legend
        columns: 3
        typography: tab.typography
        scheme: tab.scheme
    }

    Components.MoneyLine {
        Layout.fillWidth: true
        typography: tab.typography
        amounts: tab.status === "ready" ? Chart.money(tab.figures, tab.prices) : null
        currency: tab.currency
        language: tab.language
        scheme: tab.scheme
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Charts.BarChart {
            id: chart

            anchors.fill: parent
            visible: tab.status === "ready"
            bars: Chart.stacks(tab.rows, tab.sources, tab.uses)
            labels: tab.rows.map(row => I18n.barLabel(tab.language, tab.scale, row.key))
            colours: tab.quantityColours
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
        text: I18n.t(tab.language, "history.hint")
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
