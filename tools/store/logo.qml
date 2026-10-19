import QtQuick
import "../../package/contents/ui/flow/icons" as Icons

// The product picture: the solar node of the graph, alone on the black of the widget.
Item {
    width: 512
    height: 512

    Rectangle {
        anchors.fill: parent
        radius: 112
        color: "#000000"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 360 + 36
        height: width
        radius: 360 * 0.26 + 18
        color: "#ffc53d"
        opacity: 0.16
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 360
        height: 360
        radius: 360 * 0.26
        color: "#0c0f15"
        border.width: 7
        border.color: "#ffc53d"

        Icons.SolarIcon {
            anchors.fill: parent
            anchors.margins: 360 * 0.17
            tint: "#ffc53d"
            active: true
            clock: 0
            strength: 0.7
        }
    }
}
