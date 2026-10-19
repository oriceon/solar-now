import QtQuick

import "../components" as Components

/** A ring split into shares, with what it adds up to written in its middle. */
Item {
    id: donut

    /** shares() of code/chart.mjs, each with the `colour` of its part, as text. */
    required property var parts
    /** What the whole is, and how much. */
    required property string title
    required property string totalText
    required property var typography
    /** `{ text, secondary, edge }`, see `scheme` in FullRepresentation. */
    required property var scheme

    readonly property real side: Math.min(width, height)
    readonly property string signature: JSON.stringify([parts, scheme.edge, side])

    Canvas {
        id: ring

        anchors.centerIn: parent
        width: donut.side
        height: donut.side

        onPaint: {
            const context = getContext("2d");
            const centre = width / 2;
            const thickness = Math.max(6, width * 0.13);
            const radius = centre - thickness / 2 - 1;
            // A ring starts at the top and runs clockwise.
            const angle = share => (share - 0.25) * 2 * Math.PI;
            // A sliver of nothing between two parts tells them apart.
            const gap = donut.parts.length > 1 ? 0.006 : 0;

            context.reset();
            context.clearRect(0, 0, width, height);

            // Before the tab has laid it out, the ring has no room to be drawn in.
            if (radius <= 0) {
                return;
            }

            context.lineWidth = thickness;

            if (donut.parts.length === 0) {
                context.strokeStyle = donut.scheme.edge;
                context.beginPath();
                context.arc(centre, centre, radius, 0, 2 * Math.PI);
                context.stroke();

                return;
            }

            donut.parts.forEach(part => {
                if (part.to - part.from <= 2 * gap) {
                    return;
                }

                context.strokeStyle = part.colour;
                context.beginPath();
                context.arc(centre, centre, radius, angle(part.from + gap), angle(part.to - gap));
                context.stroke();
            });
        }
    }

    Column {
        anchors.centerIn: parent
        width: donut.side * 0.62

        Components.Label {
            width: parent.width
            typography: donut.typography
            relativeSize: 0.78
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: donut.scheme.secondary
            text: donut.title
        }

        Components.Label {
            width: parent.width
            typography: donut.typography
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            minimumPointSize: 6
            color: donut.scheme.text
            text: donut.totalText
        }
    }

    onSignatureChanged: ring.requestPaint()
}
