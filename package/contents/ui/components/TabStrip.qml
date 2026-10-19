pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

/** The tabs of the widget, as pills; drawn by the widget so that they read on its black background. */
RowLayout {
    id: strip

    /** What every pill says, in order. */
    required property var labels
    /** Index of the pill that is on. */
    required property int current
    required property var typography
    /** `{ text, secondary }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** Size of the text relative to the base size of the widget. */
    property real relativeSize: 0.9
    /** True for pills of the same width; otherwise each is as wide as its name asks for. */
    property bool equal: false

    signal picked(int index)

    spacing: 2

    Repeater {
        model: strip.labels

        delegate: Rectangle {
            id: pill

            required property string modelData
            required property int index

            readonly property bool on: index === strip.current

            // What room is left, or missing, is shared between the pills.
            Layout.fillWidth: true
            Layout.preferredWidth: strip.equal ? 1 : widest.advanceWidth + 14
            Layout.minimumWidth: 12
            implicitHeight: Math.round(name.implicitHeight * 1.7)
            radius: height / 2
            color: on ? Qt.alpha(strip.scheme.text, 0.15) : touch.containsMouse ? Qt.alpha(strip.scheme.text, 0.07) : "transparent"

            Label {
                id: name

                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 4)
                typography: strip.typography
                relativeSize: strip.relativeSize
                font.weight: pill.on ? Font.DemiBold : Font.Normal
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: pill.on ? strip.scheme.text : strip.scheme.secondary
                text: pill.modelData
            }

            // The name in its heavier weight, so that a pill does not change width when it is picked.
            TextMetrics {
                id: widest

                font.family: strip.typography.family
                font.pointSize: strip.typography.size * strip.relativeSize
                font.weight: Font.DemiBold
                text: pill.modelData
            }

            MouseArea {
                id: touch

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: strip.picked(pill.index)
            }
        }
    }
}
