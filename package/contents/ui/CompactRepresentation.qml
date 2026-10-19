pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/format.mjs" as Format
import "flow/icons" as Icons

MouseArea {
    id: compact

    /** buildFlow() of code/flow.mjs, null until any data was loaded. */
    required property var flow
    /** False while that flow is not the one of the configured station; the panel then shows the icon alone. */
    required property bool live
    /** What to show, in order: battery, solar, load, grid. */
    required property var items
    /** Colour of every source and consumer, as text: `{ solar, grid, battery, load }`. */
    required property var colours
    required property string warningColour
    /** auto | w | kw */
    required property string powerUnit
    required property string language
    /** Percent under which the battery is drawn as low. */
    required property real lowBattery

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real iconSide: Math.min(Kirigami.Units.iconSizes.smallMedium, vertical ? width : height)
    readonly property bool showing: live && flow !== null
    readonly property bool batteryLow: flow !== null && flow.battery.soc !== null && flow.battery.soc < lowBattery
    readonly property var icons: ({ battery: batteryIcon, solar: solarIcon, load: loadIcon, grid: gridIcon })
    /** The settings hand over a list that is not a JavaScript array. */
    readonly property var shown: {
        const ids = [];

        for (let index = 0; index < items.length; index++) {
            if (icons[String(items[index])] !== undefined) {
                ids.push(String(items[index]));
            }
        }

        return ids;
    }

    function textFor(id: string): string {
        return id === "battery" ? Format.percent(flow.battery.soc) : Format.power(flow[id].power, powerUnit, language);
    }

    // With nothing but the icon to show, the icon still needs its room.
    Layout.minimumWidth: vertical ? 0 : showing ? content.implicitWidth + Kirigami.Units.smallSpacing * 2 : iconSide
    Layout.minimumHeight: vertical ? content.implicitHeight : 0

    Kirigami.Icon {
        anchors.centerIn: parent
        width: compact.iconSide
        height: width
        visible: !compact.showing
        source: Plasmoid.icon
    }

    GridLayout {
        id: content

        anchors.centerIn: parent
        visible: compact.showing
        columns: compact.vertical ? 1 : Math.max(1, compact.shown.length)
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Repeater {
            model: compact.showing ? compact.shown : []

            delegate: RowLayout {
                id: entry

                required property string modelData

                Layout.alignment: Qt.AlignCenter
                spacing: Kirigami.Units.smallSpacing

                Loader {
                    Layout.preferredWidth: compact.iconSide
                    Layout.preferredHeight: compact.iconSide
                    sourceComponent: compact.icons[entry.modelData]
                }

                PlasmaComponents.Label {
                    text: compact.textFor(entry.modelData)
                }
            }
        }
    }

    // A panel is no place for motion: the clocks of the icons stand still.
    Component {
        id: batteryIcon

        Icons.BatteryIcon {
            tint: compact.batteryLow ? compact.warningColour : compact.colours.battery
            levelColour: tint
            soc: compact.flow.battery.soc
            direction: 0
            clock: 0
            // The percentage is written next to the icon here.
            percentText: ""
            fontFamily: Kirigami.Theme.defaultFont.family
        }
    }

    Component {
        id: solarIcon

        Icons.SolarIcon {
            tint: compact.colours.solar
            active: compact.flow.solar.direction !== 0
            clock: 0
            strength: 0
        }
    }

    Component {
        id: loadIcon

        Icons.HomeIcon {
            tint: compact.colours.load
            active: compact.flow.load.direction !== 0
            clock: 0
            strength: 0
        }
    }

    Component {
        id: gridIcon

        Icons.GridIcon {
            tint: compact.colours.grid
            active: compact.flow.grid.direction !== 0
            clock: 0
            exporting: compact.flow.grid.state === "export"
        }
    }
}
