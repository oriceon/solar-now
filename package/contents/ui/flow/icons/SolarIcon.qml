import QtQuick

/** A solar panel under a sun whose rays turn while the panels produce. */
Item {
    id: icon

    /** Colour of the drawing, as text. */
    required property string tint
    /** Whether the panels produce. */
    required property bool active
    /** Seconds the graph has been animating; it stands still while nothing should move. */
    required property real clock
    /** 0…1, how much is produced; the rays turn faster with it. */
    required property real strength

    /** The drawing is laid out on a grid of 48 × 48. */
    readonly property real unit: Math.min(width, height) / 48
    readonly property real sunX: 34
    readonly property real sunY: 11
    readonly property real raysSide: 22

    function repaint(): void {
        panel.requestPaint();
        rays.requestPaint();
    }

    Canvas {
        id: panel

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineCap = "round";
            context.lineJoin = "round";
            context.strokeStyle = icon.tint;
            context.fillStyle = icon.tint;

            // The panel, tilted back: narrower at the top than at the bottom.
            context.beginPath();
            context.moveTo(11, 24);
            context.lineTo(33, 24);
            context.lineTo(39, 43);
            context.lineTo(5, 43);
            context.closePath();
            context.globalAlpha = 0.16;
            context.fill();
            context.globalAlpha = 1;
            context.lineWidth = 2.4;
            context.stroke();

            // Its cells.
            context.lineWidth = 1.5;
            context.beginPath();
            context.moveTo(18.3, 24);
            context.lineTo(16.3, 43);
            context.moveTo(25.7, 24);
            context.lineTo(27.7, 43);
            context.moveTo(8.1, 33.2);
            context.lineTo(35.9, 33.2);
            context.stroke();

            context.lineWidth = 2.2;
            context.beginPath();
            context.arc(icon.sunX, icon.sunY, 4, 0, 2 * Math.PI);
            context.stroke();
        }
    }

    Canvas {
        id: rays

        readonly property int count: 8

        x: (icon.sunX - icon.raysSide / 2) * icon.unit
        y: (icon.sunY - icon.raysSide / 2) * icon.unit
        width: icon.raysSide * icon.unit
        height: width
        rotation: icon.active ? (icon.clock * (10 + 36 * icon.strength)) % 360 : 0
        opacity: icon.active ? 1 : 0.55

        onPaint: {
            const context = getContext("2d");
            const centre = icon.raysSide / 2;

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(icon.unit, icon.unit);
            context.lineCap = "round";
            context.lineWidth = 2;
            context.strokeStyle = icon.tint;
            context.beginPath();

            for (let ray = 0; ray < count; ray++) {
                const angle = ray * 2 * Math.PI / count;

                context.moveTo(centre + Math.cos(angle) * 6.8, centre + Math.sin(angle) * 6.8);
                context.lineTo(centre + Math.cos(angle) * 9.6, centre + Math.sin(angle) * 9.6);
            }

            context.stroke();
        }
    }

    onTintChanged: repaint()
    onUnitChanged: repaint()
}
