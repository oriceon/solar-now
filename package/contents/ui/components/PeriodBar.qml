import QtQuick
import QtQuick.Layouts

/** The period a tab shows, with a step back and a step forward, and optionally the choice between kinds of period. */
RowLayout {
    id: bar

    /** The name of the period on show. */
    required property string label
    required property bool canGoBack
    required property bool canGoForward
    required property var typography
    /** `{ text, secondary }`, see `scheme` in FullRepresentation. */
    required property var scheme
    /** Names of the kinds of period to choose from; empty for a tab with a single kind. */
    property var scales: []
    property int currentScale: 0

    signal stepped(int steps)
    signal scalePicked(int index)

    spacing: 4

    FontMetrics {
        id: scaleMetrics

        font.family: bar.typography.family
        font.pointSize: bar.typography.size * 0.82
    }

    TabStrip {
        // As wide as its longest name asks for, three times over; a width taken from the bar itself would chase its own tail.
        Layout.preferredWidth: {
            // Read so that the names are measured again when the font changes: a call alone does not notice.
            const measuredFont = scaleMetrics.font;
            let widest = 0;

            for (let index = 0; index < bar.scales.length; index++) {
                widest = Math.max(widest, scaleMetrics.advanceWidth(bar.scales[index]));
            }

            return Math.ceil((widest + 18) * bar.scales.length);
        }
        visible: bar.scales.length > 0
        equal: true
        labels: bar.scales
        current: bar.currentScale
        typography: bar.typography
        scheme: bar.scheme
        relativeSize: 0.82

        onPicked: index => bar.scalePicked(index)
    }

    Item {
        Layout.fillWidth: true
    }

    Label {
        typography: bar.typography
        relativeSize: 1.25
        opacity: bar.canGoBack ? 1 : 0.25
        color: bar.scheme.text
        text: "‹"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            enabled: bar.canGoBack
            cursorShape: Qt.PointingHandCursor

            onClicked: bar.stepped(-1)
        }
    }

    Label {
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        typography: bar.typography
        font.weight: Font.DemiBold
        color: bar.scheme.text
        text: bar.label
    }

    Label {
        typography: bar.typography
        relativeSize: 1.25
        opacity: bar.canGoForward ? 1 : 0.25
        color: bar.scheme.text
        text: "›"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            enabled: bar.canGoForward
            cursorShape: Qt.PointingHandCursor

            onClicked: bar.stepped(1)
        }
    }

    Item {
        Layout.fillWidth: true
        visible: bar.scales.length === 0
    }
}
