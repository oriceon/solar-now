pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/** A colour picked from a few swatches, or typed as #rrggbb. */
RowLayout {
    id: choice

    /** The colour on hand, as #rrggbb. */
    required property string colour

    readonly property var swatches: ["#ffc53d", "#ff8a3d", "#ff6b6b", "#f472b6", "#8b9dff", "#4cc9f0", "#3ddc97", "#f4f6fa"]

    signal picked(string colour)

    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: choice.swatches

        delegate: Rectangle {
            id: swatch

            required property string modelData

            readonly property bool current: choice.colour.toLowerCase() === modelData

            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            radius: width / 2
            color: modelData
            border.width: current ? 3 : 1
            border.color: current ? Kirigami.Theme.textColor : Qt.alpha(Kirigami.Theme.textColor, 0.3)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: choice.picked(swatch.modelData)
            }
        }
    }

    QQC2.TextField {
        id: field

        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        maximumLength: 7

        validator: RegularExpressionValidator {
            regularExpression: /^#[0-9a-fA-F]{6}$/
        }

        // Only reached with a valid colour: the validator holds back anything else.
        onEditingFinished: choice.picked(text.toLowerCase())
        Component.onCompleted: text = choice.colour
    }

    // Typing breaks a binding, so the field is told about a colour picked elsewhere.
    onColourChanged: field.text = colour
}
