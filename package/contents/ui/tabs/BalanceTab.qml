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

/** Where the consumption of a period came from and where its production went, as two rings, and how independent of the grid that made the house. */
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
    readonly property string key: archive.historyKey(scale, anchor)
    readonly property var entry: archive.entries[key] !== undefined ? archive.entries[key] : null
    readonly property var rows: entry !== null && entry.data !== null ? entry.data : []
    /** loading, failed, empty or ready */
    readonly property string status: rows.length > 0 ? "ready" : entry === null || entry.status === "loading" ? "loading" : entry.status === "failed" ? "failed" : "empty"
    readonly property var result: Chart.balance(Chart.totals(rows))
    /** The two rings: what each is of, how much, and its parts in the colour of where they came from or went. */
    readonly property var rings: [
        {
            title: I18n.t(language, "balance.consumption"),
            total: result.consumption.total,
            parts: tab.ring([
                { key: "solar", value: result.consumption.solar, colour: colours.solar },
                { key: "battery", value: result.consumption.battery, colour: colours.battery },
                { key: "grid", value: result.consumption.grid, colour: colours.grid },
            ]),
        },
        {
            title: I18n.t(language, "balance.production"),
            total: result.production.total,
            parts: tab.ring([
                { key: "direct", value: result.production.direct, colour: colours.load },
                { key: "charge", value: result.production.charge, colour: colours.battery },
                { key: "export", value: result.production.export, colour: colours.grid },
            ]),
        },
    ]
    readonly property var gauges: [
        { title: "balance.selfSufficiency", hint: "balance.selfSufficiencyHint", share: result.selfSufficiency },
        { title: "balance.selfConsumption", hint: "balance.selfConsumptionHint", share: result.selfConsumption },
    ]

    signal scalePicked(string scale)
    signal anchorPicked(string anchor)

    /** shares() of the parts, each keeping its colour and getting the words that name it. */
    function ring(parts: var): var {
        const colourOf = {};

        parts.forEach(part => {
            colourOf[part.key] = part.colour;
        });

        return Chart.shares(parts).map(part => Object.assign(part, {
            colour: colourOf[part.key],
            label: I18n.t(language, `balance.${part.key}`),
            value: `${Format.energy(part.value, language)} · ${Format.percent(part.share * 100)}`,
        }));
    }

    function load(): void {
        archive.loadHistory(scale, anchor, Period.anchorFor(scale, today));
    }

    spacing: Kirigami.Units.smallSpacing

    Components.PeriodBar {
        Layout.fillWidth: true
        label: I18n.periodLabel(tab.language, tab.scale, tab.anchor)
        canGoBack: tab.scale !== "total"
        canGoForward: Period.canGoForward(tab.scale, tab.anchor, tab.today)
        scales: tab.scaleIds.map(id => I18n.t(tab.language, `scale.${id}`))
        currentScale: tab.scaleIds.indexOf(tab.scale)
        typography: tab.typography
        scheme: tab.scheme

        onStepped: steps => tab.anchorPicked(Period.shiftAnchor(tab.scale, tab.anchor, steps))
        onScalePicked: index => tab.scalePicked(tab.scaleIds[index])
    }

    Components.Notice {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tab.status !== "ready"
        typography: tab.typography
        scheme: tab.scheme
        text: I18n.t(tab.language, `tabstate.${tab.status}`)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: tab.status === "ready"
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: tab.rings

            delegate: ColumnLayout {
                id: half

                required property var modelData

                Layout.fillWidth: true
                // Two equal halves, whatever the texts inside need.
                Layout.preferredWidth: 1
                spacing: Kirigami.Units.smallSpacing

                Charts.Donut {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 5
                    parts: half.modelData.parts
                    title: half.modelData.title
                    totalText: Format.energy(half.modelData.total, tab.language)
                    typography: tab.typography
                    scheme: tab.scheme
                }

                Components.Legend {
                    Layout.fillWidth: true
                    items: half.modelData.parts
                    columns: 1
                    typography: tab.typography
                    scheme: tab.scheme
                }
            }
        }
    }

    Components.MoneyLine {
        Layout.fillWidth: true
        typography: tab.typography
        amounts: tab.status === "ready" ? Chart.money(Chart.totals(tab.rows), tab.prices) : null
        currency: tab.currency
        language: tab.language
        scheme: tab.scheme
    }

    RowLayout {
        Layout.fillWidth: true
        visible: tab.status === "ready"
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: tab.gauges

            delegate: Rectangle {
                id: gauge

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: words.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: Kirigami.Units.cornerRadius
                color: tab.scheme.card
                border.width: 1
                border.color: tab.scheme.edge

                Column {
                    id: words

                    anchors.verticalCenter: parent.verticalCenter
                    x: Kirigami.Units.smallSpacing * 2
                    width: parent.width - x * 2

                    Components.Label {
                        width: parent.width
                        typography: tab.typography
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: tab.scheme.text
                        text: `${I18n.t(tab.language, gauge.modelData.title)} ${gauge.modelData.share === null ? "–" : Format.percent(gauge.modelData.share * 100)}`
                    }

                    Components.Label {
                        width: parent.width
                        typography: tab.typography
                        relativeSize: 0.78
                        wrapMode: Text.WordWrap
                        color: tab.scheme.secondary
                        text: I18n.t(tab.language, gauge.modelData.hint)
                    }
                }
            }
        }
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
