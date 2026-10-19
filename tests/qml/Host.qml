import QtQuick
import org.kde.kirigami as Kirigami

// A stand-in for the desktop, and for the frame Plasma draws around a widget that asks for one.
Rectangle {
    id: host

    /** False for a widget that draws its own background, as this one does by default. */
    property bool framed: false

    color: Kirigami.Theme.dark ? "#3b1560" : "#9fb6cc"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 6
        color: host.framed ? Kirigami.Theme.backgroundColor : "transparent"

        Item {
            objectName: "content"
            anchors.fill: parent
            anchors.margins: host.framed ? 10 : 0
        }
    }
}
