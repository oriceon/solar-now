pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../components" as Components
import "../flow" as FlowUi

/** What flows right now, and under it what the day has added up to so far. */
ColumnLayout {
    id: tab

    /** buildFlow() of code/flow.mjs. */
    required property var flow
    /** parseDay() of code/deye.mjs for today, null while unknown. */
    required property var day
    required property bool showTotals
    required property string language
    required property var typography
    required property var scheme
    required property var colours
    required property string warningColour
    required property string animations
    required property string powerUnit
    required property real lowBattery
    /** Bigger text needs more room per figure. */
    required property real roomFactor
    /** Capacity of the battery in kWh, null while unknown. */
    required property var batteryCapacity
    required property real batteryReserve
    /** `{ today, tomorrow }`, each expectedProduction() of code/forecast.mjs or null; null when there is no estimate to show. */
    required property var forecast

    /** "Estimare de producție: azi circa 12,4 kWh, mâine circa 32,0 kWh", with whichever of the two is known. */
    readonly property string forecastSummary: {
        if (forecast === null) {
            return "";
        }

        const parts = [];

        ["today", "tomorrow"].forEach(day => {
            if (forecast[day] !== null) {
                parts.push(I18n.t(language, `forecast.${day}`, { value: Format.energy(forecast[day].kwh, language) }));
            }
        });

        return parts.length > 0 ? `${I18n.t(language, "forecast.title")}: ${parts.join(", ")}` : "";
    }
    /** Where the radiation comes from, as a link: the licence of Open-Meteo asks for it to be named. */
    readonly property string forecastSource: I18n.t(language, "forecast.source", { source: '<a href="https://open-meteo.com/">Open-Meteo</a>' })
    /** The estimate, with its source on a line of its own. */
    readonly property string forecastText: forecastSummary !== "" ? `${forecastSummary}<br>${forecastSource}` : ""

    /**
     * What gives way when the graph is short of room, so that no node covers the text of another:
     * first the estimate, then the totals of the day.
     */
    readonly property bool totalsShown: showTotals && day !== null && graphRoom(false, true) >= graph.neededHeight
    readonly property bool forecastShown: forecastText !== "" && graphRoom(true, totalsShown) >= graph.neededHeight
    readonly property int totalsColumns: width / 4 >= Kirigami.Units.gridUnit * 5.6 * roomFactor ? 4 : 2
    /** Height of the estimate: each of its two lines, as wide as it is, broken over lines as wide as the tab. */
    readonly property real forecastHeight: (linesFor(summaryMeasure.advanceWidth) + linesFor(sourceMeasure.advanceWidth)) * forecastMetrics.lineSpacing
    /** Height of the totals: one or two rows of cards, each a caption over a figure. */
    readonly property real totalsHeight: {
        const rows = totalsColumns === 4 ? 1 : 2;
        const card = captionMetrics.lineSpacing + figureMetrics.lineSpacing + Kirigami.Units.smallSpacing * 2;

        return rows * card + (rows - 1) * Kirigami.Units.smallSpacing;
    }

    readonly property var totals: [
        { key: "generation", colour: colours.solar },
        { key: "consumption", colour: colours.load },
        { key: "purchase", colour: colours.grid },
        { key: "feedIn", colour: colours.grid },
    ]

    spacing: Kirigami.Units.smallSpacing

    /** How many lines a text this wide takes in the tab, with room for where the words break. */
    function linesFor(textWidth: real): int {
        return Math.ceil(textWidth * 1.1 / Math.max(1, width));
    }

    /** Height left to the graph with the estimate and the totals shown or not. */
    function graphRoom(withForecast: bool, withTotals: bool): real {
        return height - (withForecast ? forecastHeight + spacing : 0) - (withTotals ? totalsHeight + spacing : 0);
    }

    FontMetrics {
        id: forecastMetrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size * 0.82
    }

    TextMetrics {
        id: summaryMeasure

        font: forecastMetrics.font
        text: tab.forecastSummary
    }

    TextMetrics {
        id: sourceMeasure

        font: forecastMetrics.font
        // The line as it reads, without the markup of the link.
        text: tab.forecastSource.replace(/<[^>]+>/g, "")
    }

    FontMetrics {
        id: captionMetrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size * 0.78
    }

    FontMetrics {
        id: figureMetrics

        font.family: tab.typography.family
        font.pointSize: tab.typography.size
    }

    FlowUi.FlowGraph {
        id: graph

        Layout.fillWidth: true
        Layout.fillHeight: true
        flow: tab.flow
        language: tab.language
        typography: tab.typography
        scheme: tab.scheme
        colours: tab.colours
        warningColour: tab.warningColour
        animations: tab.animations
        powerUnit: tab.powerUnit
        lowBattery: tab.lowBattery
        batteryCapacity: tab.batteryCapacity
        batteryReserve: tab.batteryReserve
    }

    Components.Label {
        id: forecastLine

        Layout.fillWidth: true
        visible: tab.forecastShown
        typography: tab.typography
        relativeSize: 0.82
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: tab.scheme.secondary
        linkColor: Kirigami.Theme.linkColor
        textFormat: Text.StyledText
        text: tab.forecastText

        onLinkActivated: link => Qt.openUrlExternally(link)

        HoverHandler {
            cursorShape: forecastLine.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    GridLayout {
        Layout.fillWidth: true
        visible: tab.totalsShown
        // Four in a row while each has room for its text, two rows of two on a narrow widget.
        columns: tab.totalsColumns
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Repeater {
            model: tab.totals

            delegate: Rectangle {
                id: total

                required property var modelData

                Layout.fillWidth: true
                // Equal shares, whatever the texts inside need.
                Layout.preferredWidth: 1
                implicitHeight: figures.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: Kirigami.Units.cornerRadius
                color: tab.scheme.card
                border.width: 1
                border.color: tab.scheme.edge

                Column {
                    id: figures

                    anchors.verticalCenter: parent.verticalCenter
                    x: Kirigami.Units.smallSpacing * 2
                    width: parent.width - x * 2

                    Components.Label {
                        width: parent.width
                        typography: tab.typography
                        relativeSize: 0.78
                        elide: Text.ElideRight
                        // Lighter than the other secondary texts: small, on a dark card, it read too faint.
                        color: Qt.tint(tab.scheme.secondary, Qt.alpha(tab.scheme.text, 0.45))
                        text: I18n.t(tab.language, `totals.${total.modelData.key}`)
                    }

                    Components.Label {
                        width: parent.width
                        typography: tab.typography
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: tab.scheme.colourfulText ? total.modelData.colour : tab.scheme.text
                        text: tab.day !== null ? Format.energy(tab.day[total.modelData.key], tab.language) : ""
                    }
                }
            }
        }
    }
}
