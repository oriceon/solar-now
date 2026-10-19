import QtQuick

/** A round arrow that turns while a refresh is running; drawn by the widget so that it shows on any background. */
Item {
    id: button

    /** Colour of the arrow, as text. */
    required property string colour
    required property bool busy
    /** Read by screen readers and shown nowhere else. */
    required property string label

    signal clicked()

    implicitWidth: 22
    implicitHeight: 22
    opacity: touch.containsMouse ? 1 : 0.75

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: button.clicked()

    Canvas {
        id: arrow

        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");
            const unit = Math.min(width, height) / 22;

            context.reset();
            context.clearRect(0, 0, width, height);
            context.scale(unit, unit);
            context.lineCap = "round";
            context.lineJoin = "round";
            context.lineWidth = 1.9;
            context.strokeStyle = button.colour;
            context.fillStyle = button.colour;

            // A circle open at the top, drawn clockwise, with the arrowhead where it ends.
            context.beginPath();
            context.arc(11, 11, 6.6, -0.35 * Math.PI, 1.35 * Math.PI);
            context.stroke();
            context.beginPath();
            context.moveTo(11.2, 3.5);
            context.lineTo(9, 8.2);
            context.lineTo(6, 2.6);
            context.closePath();
            context.fill();
        }
    }

    RotationAnimation on rotation {
        running: button.busy
        from: 0
        to: 360
        duration: 1100
        loops: Animation.Infinite
    }

    MouseArea {
        id: touch

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !button.busy

        onClicked: button.clicked()
    }

    onColourChanged: arrow.requestPaint()
    onBusyChanged: {
        if (!busy) {
            rotation = 0;
        }
    }
}
