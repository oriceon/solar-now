import QtQuick

/** A line of text in the middle of a tab that has nothing else to show. */
Item {
    id: notice

    required property string text
    required property var typography
    /** `{ text, secondary }`, see `scheme` in FullRepresentation. */
    required property var scheme

    Label {
        anchors.centerIn: parent
        width: parent.width - 24
        typography: notice.typography
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: notice.scheme.secondary
        text: notice.text
    }
}
