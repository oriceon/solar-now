pragma ComponentBehavior: Bound

import QtQuick

import "../../code/chart.mjs" as Chart
import "../../code/period.mjs" as Period
import "../components" as Components

/**
 * The powers of a day as lines over its 24 hours, in kilowatts on the left, with the charge of
 * the battery as a dashed line in percent on the right.
 */
Item {
    id: chart

    /** daySeries() of code/chart.mjs. */
    required property var series
    /** parseFrames() of code/deye.mjs, to find what is under the pointer. */
    required property var frames
    /** The moment the day starts, in seconds since 1970. */
    /** The day on show, yyyy-MM-dd. */
    required property string day
    /** Colour of every line, as text: `{ generation, consumption, grid, battery, soc }`. */
    required property var colours
    required property var typography
    /** `{ text, secondary, edge }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** Decimal mark of the language: "," or ".". */
    required property string decimalMark

    /** Index of the frame under the pointer, -1 while it is elsewhere. */
    property int hovered: -1

    readonly property var powerLines: ["battery", "grid", "consumption", "generation"]
    readonly property real leftRoom: Math.ceil(textMetrics.advanceWidth("-88,8")) + 6
    readonly property real rightRoom: Math.ceil(textMetrics.advanceWidth("100")) + 6
    readonly property real bottomRoom: Math.ceil(textMetrics.height) + 4
    readonly property real plotX: leftRoom
    readonly property real plotY: Math.ceil(textMetrics.height / 2)
    readonly property real plotWidth: Math.max(1, width - leftRoom - rightRoom)
    readonly property real plotHeight: Math.max(1, height - plotY - bottomRoom)
    /** Kilowatts from the lowest to the highest reading of the day, on round numbers. */
    readonly property var scale: {
        let low = 0;
        let high = 0.1;

        powerLines.forEach(name => {
            series[name].forEach(point => {
                low = Math.min(low, point[1] / 1000);
                high = Math.max(high, point[1] / 1000);
            });
        });

        return Chart.niceScale(low, high, Math.max(3, Math.min(8, Math.round(plotHeight / 30))));
    }
    /** An hour mark every three hours, or every six on a narrow chart. */
    readonly property var hours: plotWidth > 300 ? [0, 3, 6, 9, 12, 15, 18, 21, 24] : [0, 6, 12, 18, 24]
    /** Midnight to midnight on the clock of the computer: 25 hours the day the clocks go back, 23 the day they go forward. */
    readonly property var bounds: Period.dayBounds(day)
    readonly property string signature: JSON.stringify([series, bounds, colours, scale, hours, scheme.edge, width, height])

    function xOf(time: real): real {
        return plotX + (time - bounds.start) / (bounds.end - bounds.start) * plotWidth;
    }

    function yOfPower(kilowatts: real): real {
        return plotY + (scale.max - kilowatts) / (scale.max - scale.min) * plotHeight;
    }

    function yOfPercent(percent: real): real {
        return plotY + (100 - percent) / 100 * plotHeight;
    }

    function trace(context: var, points: var, yOf: var, divisor: real): void {
        context.beginPath();

        for (let index = 0; index < points.length; index++) {
            const x = xOf(points[index][0]);
            const y = yOf(points[index][1] / divisor);

            if (index === 0) {
                context.moveTo(x, y);
            } else {
                context.lineTo(x, y);
            }
        }

        context.stroke();
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

            context.reset();
            context.clearRect(0, 0, width, height);
            context.lineJoin = "round";
            context.lineCap = "round";

            // The marks of the kilowatt scale, the one at zero stronger than the rest.
            chart.scale.ticks.forEach(mark => {
                const y = Math.round(chart.yOfPower(mark)) + 0.5;

                context.strokeStyle = chart.scheme.edge;
                context.globalAlpha = mark === 0 ? 1 : 0.55;
                context.lineWidth = 1;
                context.beginPath();
                context.moveTo(chart.plotX, y);
                context.lineTo(chart.plotX + chart.plotWidth, y);
                context.stroke();
            });

            context.globalAlpha = 1;
            context.lineWidth = 1.2;
            context.strokeStyle = chart.colours.soc;
            context.setLineDash([3, 3]);
            chart.trace(context, chart.series.soc, chart.yOfPercent, 1);
            context.setLineDash([]);

            context.lineWidth = 1.7;
            chart.powerLines.forEach(name => {
                context.strokeStyle = chart.colours[name];
                chart.trace(context, chart.series[name], chart.yOfPower, 1000);
            });
        }
    }

    Repeater {
        model: chart.scale.ticks

        delegate: Components.Label {
            required property real modelData

            x: 0
            y: chart.yOfPower(modelData) - height / 2
            width: chart.leftRoom - 6
            typography: chart.typography
            relativeSize: 0.75
            horizontalAlignment: Text.AlignRight
            color: chart.scheme.secondary
            text: String(modelData).replace(".", chart.decimalMark)
        }
    }

    Repeater {
        model: [0, 50, 100]

        delegate: Components.Label {
            required property int modelData

            x: chart.plotX + chart.plotWidth + 6
            y: chart.yOfPercent(modelData) - height / 2
            typography: chart.typography
            relativeSize: 0.75
            color: chart.colours.soc
            opacity: 0.8
            text: String(modelData)
        }
    }

    Repeater {
        model: chart.hours

        delegate: Components.Label {
            required property int modelData

            x: chart.xOf(Period.hourMark(chart.day, modelData)) - width / 2
            y: chart.plotY + chart.plotHeight + 4
            typography: chart.typography
            relativeSize: 0.75
            color: chart.scheme.secondary
            text: `0${modelData}`.slice(-2)
        }
    }

    Rectangle {
        visible: chart.hovered >= 0 && chart.hovered < chart.frames.length
        x: visible ? Math.round(chart.xOf(chart.frames[chart.hovered].time)) : 0
        y: chart.plotY
        width: 1
        height: chart.plotHeight
        color: chart.scheme.text
        opacity: 0.5
    }

    MouseArea {
        x: chart.plotX
        y: chart.plotY
        width: chart.plotWidth
        height: chart.plotHeight
        hoverEnabled: true

        onPositionChanged: mouse => chart.hovered = Chart.nearestIndex(chart.frames, chart.bounds.start + mouse.x / chart.plotWidth * (chart.bounds.end - chart.bounds.start))
        onExited: chart.hovered = -1
    }

    onSignatureChanged: plot.requestPaint()
}
