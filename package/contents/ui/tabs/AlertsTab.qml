pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/i18n.mjs" as I18n
import "../components" as Components

/** What the station warned about lately, newest first. */
Item {
    id: tab

    /** ArchiveStore, or a stand-in with its answers. */
    required property QtObject archive
    required property string language
    required property var typography
    required property var scheme
    required property string warningColour

    readonly property string key: archive.alertsKey()
    readonly property var entry: archive.entries[key] !== undefined ? archive.entries[key] : null
    readonly property var alerts: entry !== null && entry.data !== null ? entry.data : []
    /** loading, failed, empty or ready */
    readonly property string status: alerts.length > 0 ? "ready" : entry === null || entry.status === "loading" ? "loading" : entry.status === "failed" ? "failed" : "empty"
    readonly property var levelColours: ({ notice: scheme.secondary, warning: "#ffb454", failure: warningColour })

    /** "13.10 12:00 – 12:10" for an alert that ended the day it started, both dates otherwise, the start alone while it is open. */
    function when(alert: var): string {
        const started = new Date(alert.startedAt * 1000);

        if (alert.endedAt === null) {
            return Qt.formatDateTime(started, "dd.MM HH:mm");
        }

        const ended = new Date(alert.endedAt * 1000);
        const sameDay = Qt.formatDate(started, "yyyyMMdd") === Qt.formatDate(ended, "yyyyMMdd");

        return `${Qt.formatDateTime(started, "dd.MM HH:mm")} – ${Qt.formatDateTime(ended, sameDay ? "HH:mm" : "dd.MM HH:mm")}`;
    }

    function load(): void {
        archive.loadAlerts();
    }

    Components.Notice {
        anchors.fill: parent
        visible: tab.status !== "ready"
        typography: tab.typography
        scheme: tab.scheme
        text: tab.status === "empty" ? I18n.t(tab.language, "alerts.none", { days: tab.archive.alertDays }) : I18n.t(tab.language, `tabstate.${tab.status}`)
    }

    ListView {
        anchors.fill: parent
        visible: tab.status === "ready"
        clip: true
        spacing: Kirigami.Units.smallSpacing
        model: tab.alerts

        delegate: Rectangle {
            id: row

            required property var modelData

            width: ListView.view.width
            height: lines.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: tab.scheme.card
            border.width: 1
            border.color: row.modelData.open ? tab.levelColours[row.modelData.level] : tab.scheme.edge

            Rectangle {
                id: mark

                anchors.verticalCenter: parent.verticalCenter
                x: Kirigami.Units.smallSpacing * 2
                width: 10
                height: 10
                radius: 5
                color: tab.levelColours[row.modelData.level]
            }

            Column {
                id: lines

                anchors.verticalCenter: parent.verticalCenter
                x: mark.x + mark.width + Kirigami.Units.smallSpacing * 2
                width: parent.width - x - Kirigami.Units.smallSpacing * 2

                Components.Label {
                    width: parent.width
                    typography: tab.typography
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    color: tab.scheme.text
                    text: row.modelData.name
                }

                Components.Label {
                    width: parent.width
                    typography: tab.typography
                    relativeSize: 0.82
                    elide: Text.ElideRight
                    color: tab.scheme.secondary
                    text: [I18n.t(tab.language, `alerts.${row.modelData.level}`), tab.when(row.modelData)].concat(row.modelData.open ? [I18n.t(tab.language, "alerts.open")] : []).join(" · ")
                }
            }
        }
    }

    Connections {
        target: tab.archive

        function onStale(): void {
            tab.load();
        }
    }

    // Later, not now: the key changes while the answer bound to it is being worked out, and loading replaces the answers.
    onKeyChanged: Qt.callLater(load)
    Component.onCompleted: load()
}
