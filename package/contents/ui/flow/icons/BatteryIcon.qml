import QtQuick

/** A battery filled as far as it is charged, with its charge written above; a shine runs through it while it charges or discharges. */
Item {
    id: icon

    /** Colour of the drawing, as text. */
    required property string tint
    /** Colour of the fill and of the percentage: the tint, or the warning colour of a low battery. */
    required property string levelColour
    /** Percent, null while unknown. */
    required property var soc
    /** -1 while it charges, 1 while it discharges, 0 at rest; see code/flow.mjs. */
    required property int direction
    /** Seconds the graph has been animating; it stands still while nothing should move. */
    required property real clock
    required property string percentText
    required property string fontFamily

    /** The drawing is laid out on a grid of 48 × 48. */
    readonly property real unit: Math.min(width, height) / 48
    readonly property real charge: soc === null ? 0 : Math.max(0, Math.min(100, soc)) / 100

    Text {
        x: 0
        y: -1 * icon.unit
        width: icon.width
        height: 17 * icon.unit
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: icon.fontFamily
        font.pixelSize: Math.max(8, 14.5 * icon.unit)
        font.weight: Font.Bold
        color: icon.levelColour
        text: icon.percentText
    }

    Rectangle {
        id: body

        x: 4 * icon.unit
        y: 20 * icon.unit
        width: 35 * icon.unit
        height: 22 * icon.unit
        radius: 4.5 * icon.unit
        color: "transparent"
        border.width: Math.max(1, 2.4 * icon.unit)
        border.color: icon.tint
    }

    Rectangle {
        x: 40.5 * icon.unit
        y: 26.5 * icon.unit
        width: 3.5 * icon.unit
        height: 9 * icon.unit
        radius: 1.4 * icon.unit
        color: icon.tint
    }

    Item {
        id: cell

        x: body.x + 4.4 * icon.unit
        y: body.y + 4.4 * icon.unit
        width: body.width - 8.8 * icon.unit
        height: body.height - 8.8 * icon.unit
        clip: true

        Rectangle {
            id: fill

            width: cell.width * icon.charge
            height: cell.height
            radius: 1.6 * icon.unit
            color: icon.levelColour
        }

        Rectangle {
            readonly property real trip: (icon.clock * 0.75) % 1
            readonly property real span: fill.width + width

            visible: icon.direction !== 0 && icon.clock !== 0
            // Rightwards while charging, leftwards while discharging.
            x: (icon.direction < 0 ? trip : 1 - trip) * span - width
            width: 6 * icon.unit
            height: cell.height
            color: "#ffffff"
            opacity: x + width > fill.width ? 0 : 0.5
        }
    }
}
