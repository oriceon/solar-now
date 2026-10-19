pragma ComponentBehavior: Bound

import QtQuick

import "../../code/chart.mjs" as Chart
import "../components" as Components

/** Energy as stacked bars: what came in above zero, what went out below it. */
Item {
    id: chart

    /** stacks() of code/chart.mjs. */
    required property var bars
    /** What stands under every bar. */
    required property var labels
    /** Colour of every quantity by its name, as text. */
    required property var colours
    required property var typography
    /** `{ text, secondary, edge }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** Decimal mark of the language: "," or ".". */
    required property string decimalMark

    /** Index of the bar under the pointer, -1 while it is elsewhere. */
    property int hovered: -1

    readonly property var extent: Chart.stackExtent(bars)
    readonly property var scale: Chart.niceScale(extent.low, Math.max(extent.high, extent.low + 0.001), Math.max(3, Math.min(8, Math.round(plotHeight / 30))))
    readonly property real leftRoom: Math.ceil(textMetrics.advanceWidth("-8888")) + 6
    readonly property real bottomRoom: Math.ceil(textMetrics.height) + 4
    readonly property real plotX: leftRoom
    readonly property real plotY: Math.ceil(textMetrics.height / 2)
    readonly property real plotWidth: Math.max(1, width - leftRoom - 4)
    readonly property real plotHeight: Math.max(1, height - plotY - bottomRoom)
    readonly property real slot: plotWidth / Math.max(1, bars.length)
    /** Only every so many bars get a label when they stand too close for all of them. */
    readonly property int labelEvery: Math.max(1, Math.ceil(textMetrics.advanceWidth("888") * 1.25 / slot))
    readonly property string signature: JSON.stringify([bars, colours, scale, scheme.edge, hovered, width, height])

    function yOf(value: real): real {
        return plotY + (scale.max - value) / (scale.max - scale.min) * plotHeight;
    }

    FontMetrics {
        id: textMetrics

        font.family: chart.typography.family
        font.pointSize: chart.typography.size * 0.75
    }

    Canvas {
        id: plot

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");
            const barWidth = Math.max(2, Math.min(34, chart.slot * 0.66));

            context.reset();
            context.clearRect(0, 0, width, height);

            chart.scale.ticks.forEach(mark => {
                const y = Math.round(chart.yOf(mark)) + 0.5;

                context.strokeStyle = chart.scheme.edge;
                context.globalAlpha = mark === 0 ? 1 : 0.55;
                context.lineWidth = 1;
                context.beginPath();
                context.moveTo(chart.plotX, y);
                context.lineTo(chart.plotX + chart.plotWidth, y);
                context.stroke();
            });

            chart.bars.forEach((bar, index) => {
                const x = chart.plotX + index * chart.slot + (chart.slot - barWidth) / 2;

                context.globalAlpha = chart.hovered === -1 || chart.hovered === index ? 1 : 0.45;

                bar.up.concat(bar.down).forEach(slice => {
                    const top = chart.yOf(Math.max(slice.from, slice.to));
                    const bottom = chart.yOf(Math.min(slice.from, slice.to));

                    context.fillStyle = chart.colours[slice.key];
                    // A hair of space between the slices of a stack tells them apart.
                    context.fillRect(x, top + 0.5, barWidth, Math.max(1, bottom - top - 1));
                });
            });
        }
    }

    Repeater {
        model: chart.scale.ticks

        delegate: Components.Label {
            required property real modelData

            x: 0
            y: chart.yOf(modelData) - height / 2
            width: chart.leftRoom - 6
            typography: chart.typography
            relativeSize: 0.75
            horizontalAlignment: Text.AlignRight
            color: chart.scheme.secondary
            // Below zero is what went out, not a negative amount.
            text: String(Math.abs(modelData)).replace(".", chart.decimalMark)
        }
    }

    Repeater {
        model: chart.labels

        delegate: Components.Label {
            required property string modelData
            required property int index

            visible: index % chart.labelEvery === 0
            x: chart.plotX + (index + 0.5) * chart.slot - width / 2
            y: chart.plotY + chart.plotHeight + 4
            typography: chart.typography
            relativeSize: 0.75
            color: chart.hovered === index ? chart.scheme.text : chart.scheme.secondary
            text: modelData
        }
    }

    MouseArea {
        x: chart.plotX
        y: chart.plotY
        width: chart.plotWidth
        height: chart.plotHeight
        hoverEnabled: true

        onPositionChanged: mouse => chart.hovered = Math.max(0, Math.min(chart.bars.length - 1, Math.floor(mouse.x / chart.slot)))
        onExited: chart.hovered = -1
    }

    onSignatureChanged: plot.requestPaint()
}
