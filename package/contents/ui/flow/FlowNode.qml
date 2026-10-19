import QtQuick

import "../components" as Components

/** A source or a consumer of the graph: a card with its icon, and under it the power and what it is. */
Item {
    id: node

    required property real side
    required property color accent
    /** Whether power flows through it; an idle node is drawn without its colour. */
    required property bool active
    /** `{ text, secondary, card, edge, colourfulText }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** How strongly the accent shines around an active node, 0…1. */
    property real glow: 0.14
    required property var typography
    /** Room the text under the card may take. */
    required property real captionWidth
    required property string captionText
    property string valueText: ""
    /** A third line under the card, for what the caption has no room for; empty for none. */
    property string noteText: ""

    /** The icon; it fills the inside of the card. */
    default property alias content: holder.data

    width: side
    height: side

    Rectangle {
        anchors.centerIn: card
        width: card.width + 12
        height: width
        radius: card.radius + 6
        color: node.accent
        opacity: node.active ? node.glow : 0
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: node.side * 0.26
        color: node.scheme.card
        border.width: 1.5
        border.color: node.active ? node.accent : node.scheme.edge
    }

    Item {
        id: holder

        anchors.fill: card
        anchors.margins: node.side * 0.17
    }

    Column {
        anchors.top: card.bottom
        anchors.topMargin: 5
        anchors.horizontalCenter: card.horizontalCenter
        width: node.captionWidth

        Components.Label {
            width: parent.width
            visible: node.valueText !== ""
            typography: node.typography
            relativeSize: 1.08
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: node.scheme.text
            text: node.valueText
        }

        Components.Label {
            width: parent.width
            typography: node.typography
            relativeSize: 0.85
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: !node.active ? node.scheme.secondary : node.scheme.colourfulText ? node.accent : node.scheme.text
            text: node.captionText
        }

        Components.Label {
            width: parent.width
            visible: node.noteText !== ""
            typography: node.typography
            relativeSize: 0.78
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: node.scheme.secondary
            text: node.noteText
        }
    }
}
