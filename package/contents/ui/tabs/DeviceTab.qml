pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/i18n.mjs" as I18n
import "../../code/inverter.mjs" as Inverter
import "../components" as Components

/** Everything the inverter and the other devices of the station measure, under the names the API gives it. */
Item {
    id: tab

    /** ArchiveStore, or a stand-in with its answers. */
    required property QtObject archive
    required property string language
    required property var typography
    required property var scheme

    readonly property string key: archive.devicesKey()
    readonly property var entry: archive.entries[key] !== undefined ? archive.entries[key] : null
    readonly property var devices: entry !== null && entry.data !== null ? entry.data : []
    /** loading, failed, empty or ready */
    readonly property string status: devices.length > 0 ? "ready" : entry === null || entry.status === "loading" ? "loading" : entry.status === "failed" ? "failed" : "empty"
    /** Measure points side by side: two on a narrow widget, three with room for them. */
    readonly property int columns: width >= Kirigami.Units.gridUnit * 30 ? 3 : 2

    function load(): void {
        archive.loadDevices();
    }

    Components.Notice {
        anchors.fill: parent
        visible: tab.status !== "ready"
        typography: tab.typography
        scheme: tab.scheme
        text: I18n.t(tab.language, tab.status === "empty" ? "device.none" : `tabstate.${tab.status}`)
    }

    Flickable {
        anchors.fill: parent
        visible: tab.status === "ready"
        clip: true
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list

            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            Components.Label {
                width: parent.width
                typography: tab.typography
                relativeSize: 0.78
                wrapMode: Text.WordWrap
                color: tab.scheme.secondary
                text: I18n.t(tab.language, "device.hint")
            }

            Repeater {
                model: tab.devices

                delegate: Column {
                    id: device

                    required property var modelData

                    width: list.width
                    spacing: Kirigami.Units.smallSpacing

                    Components.Label {
                        width: parent.width
                        typography: tab.typography
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: tab.scheme.text
                        text: `${device.modelData.type} ${device.modelData.serial}` + (device.modelData.collectedAt !== null ? ` · ${I18n.t(tab.language, "device.read", { time: Qt.formatTime(new Date(device.modelData.collectedAt * 1000), "HH:mm") })}` : "")
                    }

                    // What the device measures, sorted into what it is about: panels, battery, grid and so on.
                    Repeater {
                        model: Inverter.groupPoints(device.modelData.points, tab.language)

                        delegate: Column {
                            id: group

                            required property var modelData

                            width: device.width
                            topPadding: Kirigami.Units.smallSpacing

                            Components.Label {
                                width: parent.width
                                bottomPadding: Kirigami.Units.smallSpacing
                                typography: tab.typography
                                relativeSize: 0.82
                                font.weight: Font.DemiBold
                                font.capitalization: Font.AllUppercase
                                color: tab.scheme.secondary
                                text: I18n.t(tab.language, `devicegroup.${group.modelData.id}`)
                            }

                            Flow {
                                width: parent.width

                                Repeater {
                                    model: group.modelData.points

                                    delegate: Column {
                                        id: point

                                        required property var modelData

                                        width: Math.floor(device.width / tab.columns)
                                        bottomPadding: Kirigami.Units.smallSpacing

                                        Components.Label {
                                            width: parent.width - Kirigami.Units.largeSpacing
                                            typography: tab.typography
                                            relativeSize: 0.75
                                            elide: Text.ElideRight
                                            color: tab.scheme.secondary
                                            text: point.modelData.label
                                        }

                                        Components.Label {
                                            width: parent.width - Kirigami.Units.largeSpacing
                                            typography: tab.typography
                                            relativeSize: 0.95
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            color: tab.scheme.text
                                            text: `${point.modelData.value} ${point.modelData.unit}`.trim()
                                        }
                                    }
                                }
                            }
                        }
                    }
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
