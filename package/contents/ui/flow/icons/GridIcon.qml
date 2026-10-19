pragma ComponentBehavior: Bound

import QtQuick

/** A pylon of the grid; its insulators light up one after the other while power is exchanged. */
Item {
    id: icon

    /** Colour of the drawing, as text. */
    required property string tint
    /** Whether power is bought or sold. */
    required property bool active
    /** Seconds the graph has been animating; it stands still while nothing should move. */
    required property real clock
    /** True while power is sold: the light then runs from the tower outwards. */
    required property bool exporting

    /** The drawing is laid out on a grid of 48 × 48. */
    readonly property real unit: Math.min(width, height) / 48
    /** Where the insulators hang, and how far along the wave of light each is. */
    readonly property var insulators: [
        { x: 8, y: 21, step: 0 },
        { x: 40, y: 21, step: 0 },
        { x: 12, y: 31, step: 1 },
        { x: 36, y: 31, step: 1 },
    ]

    Canvas {
        id: tower

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineCap = "round";
            context.lineJoin = "round";
            context.strokeStyle = icon.tint;

            // The legs and the two arms.
            context.lineWidth = 2.4;
            context.beginPath();
            context.moveTo(13, 44);
            context.lineTo(24, 5);
            context.lineTo(35, 44);
            context.moveTo(8, 15);
            context.lineTo(40, 15);
            context.moveTo(12, 25);
            context.lineTo(36, 25);
            context.stroke();

            // The bracing between the legs, and what the insulators hang from.
            context.lineWidth = 1.5;
            context.beginPath();
            context.moveTo(21.2, 15);
            context.lineTo(29.6, 25);
            context.moveTo(26.8, 15);
            context.lineTo(18.4, 25);
            context.moveTo(18.4, 25);
            context.lineTo(32.5, 35);
            context.moveTo(29.6, 25);
            context.lineTo(15.5, 35);
            context.moveTo(8, 15);
            context.lineTo(8, 18.5);
            context.moveTo(40, 15);
            context.lineTo(40, 18.5);
            context.moveTo(12, 25);
            context.lineTo(12, 28.5);
            context.moveTo(36, 25);
            context.lineTo(36, 28.5);
            context.stroke();
        }
    }

    Repeater {
        model: icon.insulators

        delegate: Rectangle {
            required property var modelData

            /** The wave of light reaches the lower arm later when buying, earlier when selling. */
            readonly property real phase: (icon.exporting ? 1 - modelData.step : modelData.step) * 1.6

            x: (modelData.x - 2.2) * icon.unit
            y: (modelData.y - 2.2) * icon.unit
            width: 4.4 * icon.unit
            height: width
            radius: width / 2
            color: icon.tint
            opacity: !icon.active ? 0.45 : icon.clock === 0 ? 1 : 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(icon.clock * 4.5 - phase))
        }
    }

    onTintChanged: tower.requestPaint()
    onUnitChanged: tower.requestPaint()
}
