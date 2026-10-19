import QtQuick

/** The inverter: a box with a display on which a sine wave runs while it converts power. */
Item {
    id: icon

    /** Colour of the drawing, as text. */
    required property string tint
    /** Colour of the wave and of the light, as text. */
    required property string accent
    /** Whether any power flows through it. */
    required property bool busy
    /** Seconds the graph has been animating; it stands still while nothing should move. */
    required property real clock

    /** The drawing is laid out on a grid of 48 × 48. */
    readonly property real unit: Math.min(width, height) / 48
    /** Length of one wave on the display, in grid units. */
    readonly property real period: 14

    function repaint(): void {
        box.requestPaint();
        wave.requestPaint();
    }

    Canvas {
        id: box

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineCap = "round";
            context.lineJoin = "round";
            context.strokeStyle = icon.tint;

            context.lineWidth = 2.4;
            context.beginPath();
            context.roundedRect(9, 4, 30, 40, 5.5, 5.5);
            context.stroke();

            context.lineWidth = 1.5;
            context.beginPath();
            context.roundedRect(14, 9, 20, 15, 3, 3);
            context.moveTo(25, 34.5);
            context.lineTo(33, 34.5);
            context.stroke();
        }
    }

    Item {
        x: 17 * icon.unit
        y: 11 * icon.unit
        width: icon.period * icon.unit
        height: 11 * icon.unit
        clip: true

        Canvas {
            id: wave

            // Two waves side by side: sliding the pair by one wave looks like an endless one.
            x: -((icon.busy ? icon.clock * 9 : 0) % icon.period) * icon.unit
            width: icon.period * 2 * icon.unit
            height: parent.height
            opacity: icon.busy ? 1 : 0.5

            onPaint: {
                const context = getContext("2d");
                const quarter = icon.period / 4;

                context.reset();
                context.clearRect(0, 0, width, height);
                context.scale(icon.unit, icon.unit);
                context.lineCap = "round";
                context.lineWidth = 1.8;
                context.strokeStyle = icon.accent;
                context.beginPath();
                context.moveTo(0, 5.5);

                for (let half = 0; half < 4; half++) {
                    const start = half * 2 * quarter;

                    context.quadraticCurveTo(start + quarter, half % 2 === 0 ? -1 : 12, start + 2 * quarter, 5.5);
                }

                context.stroke();
            }
        }
    }

    Rectangle {
        x: 15.6 * icon.unit
        y: 32.1 * icon.unit
        width: 4.8 * icon.unit
        height: width
        radius: width / 2
        color: icon.busy ? icon.accent : icon.tint
        opacity: !icon.busy ? 0.5 : icon.clock === 0 ? 1 : 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(icon.clock * 3))
    }

    onTintChanged: repaint()
    onAccentChanged: repaint()
    onUnitChanged: repaint()
}
