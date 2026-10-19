pragma ComponentBehavior: Bound

import QtQuick

/** What the colours of a chart stand for, each with its figure. */
Flow {
    id: legend

    /** `{ label, colour, value }` of every entry; `value` may be empty. */
    required property var items
    required property var typography
    /** `{ text, secondary }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** Entries per row; they share the width equally. */
    property int columns: 3

    spacing: 0

    Repeater {
        model: legend.items

        delegate: Item {
            id: entry

            required property var modelData

            width: Math.floor(legend.width / legend.columns)
            height: texts.implicitHeight + 4

            Rectangle {
                id: dot

                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: entry.modelData.colour
            }

            Column {
                id: texts

                anchors.verticalCenter: parent.verticalCenter
                x: dot.width + 6
                width: parent.width - x - 4

                Label {
                    width: parent.width
                    typography: legend.typography
                    relativeSize: 0.78
                    elide: Text.ElideRight
                    color: legend.scheme.secondary
                    text: entry.modelData.label
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    typography: legend.typography
                    relativeSize: 0.92
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    color: legend.scheme.text
                    text: entry.modelData.value
                }
            }
        }
    }
}
