import QtQuick

/** A button drawn by the widget itself, so that it reads the same on its black background under any Plasma theme. */
Rectangle {
    id: button

    required property string text
    required property var typography
    /** Colour of the text and of the outline, as text. */
    required property string colour

    signal clicked()

    implicitWidth: label.implicitWidth + height
    implicitHeight: label.implicitHeight * 1.9
    radius: height / 2
    color: touch.containsMouse ? Qt.alpha(button.colour, 0.16) : "transparent"
    border.width: 1.5
    border.color: button.colour

    Label {
        id: label

        anchors.centerIn: parent
        typography: button.typography
        color: button.colour
        text: button.text
    }

    MouseArea {
        id: touch

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: button.clicked()
    }
}
