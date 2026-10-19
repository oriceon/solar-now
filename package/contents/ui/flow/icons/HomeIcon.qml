import QtQuick

/** A house with a lightning bolt inside that pulses while the house consumes. */
Item {
    id: icon

    /** Colour of the drawing, as text. */
    required property string tint
    /** Whether the house consumes. */
    required property bool active
    /** Seconds the graph has been animating; it stands still while nothing should move. */
    required property real clock
    /** 0…1, how much is consumed; the bolt pulses faster with it. */
    required property real strength

    /** The drawing is laid out on a grid of 48 × 48. */
    readonly property real unit: Math.min(width, height) / 48

    function repaint(): void {
        house.requestPaint();
        bolt.requestPaint();
    }

    Canvas {
        id: house

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineCap = "round";
            context.lineJoin = "round";
            context.lineWidth = 2.4;
            context.strokeStyle = icon.tint;
            context.beginPath();
            context.moveTo(5, 24.5);
            context.lineTo(24, 7);
            context.lineTo(43, 24.5);
            context.moveTo(10, 21);
            context.lineTo(10, 43);
            context.lineTo(38, 43);
            context.lineTo(38, 21);
            context.stroke();
        }
    }

    Canvas {
        id: bolt

        anchors.fill: parent
        opacity: !icon.active ? 0.4 : icon.clock === 0 ? 1 : 0.5 + 0.5 * (0.5 + 0.5 * Math.sin(icon.clock * (2 + 5 * icon.strength)))

        onPaint: {
            const context = getContext("2d");

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineJoin = "round";
            context.fillStyle = icon.tint;
            context.beginPath();
            context.moveTo(26.6, 19.5);
            context.lineTo(18.6, 31.2);
            context.lineTo(23.4, 31.2);
            context.lineTo(21.2, 39.5);
            context.lineTo(29.6, 27.6);
            context.lineTo(24.6, 27.6);
            context.closePath();
            context.fill();
        }
    }

    onTintChanged: repaint()
    onUnitChanged: repaint()
}
