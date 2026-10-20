pragma ComponentBehavior: Bound

import QtQuick

import "../../code/battery.mjs" as Battery
import "../../code/flow.mjs" as Flow
import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n
import "../../code/layout.mjs" as Layout
import "../components" as Components
import "icons" as Icons

/**
 * The power flow around the inverter: a node for every source and consumer, a dashed line
 * to each, and dots that run along the lines the way the power does.
 */
Item {
    id: graph

    /** buildFlow() of code/flow.mjs. */
    required property var flow
    required property string language
    required property var typography
    /** Colours of the surroundings, as text: `{ text, secondary, idle, card, edge, track }`. */
    required property var scheme
    /** Colour of every source and consumer, as text: `{ solar, grid, battery, load }`. */
    required property var colours
    /** Colour of a battery under `lowBattery`, as text. */
    required property string warningColour
    /** full | reduced | off */
    required property string animations
    /** auto | w | kw */
    required property string powerUnit
    /** Percent under which the battery is drawn as low. */
    required property real lowBattery
    /** Capacity of the battery in kWh, null while unknown. */
    required property var batteryCapacity
    /** Percent under which the inverter no longer draws from the battery. */
    required property real batteryReserve

    /** Watts at which a flow is drawn at its liveliest. */
    readonly property real referencePower: 5000
    /**
     * Seconds the graph has been animating. While nothing should move it keeps
     * its value, which is what gives the still picture.
     */
    property real clock: 0
    // Nothing moves while the widget is not on screen. `Window.window` is the window the graph is in,
    // null before it is placed in one; the attached `Window` itself has no `visible`.
    readonly property bool moving: animations !== "off" && graph.Window.window !== null && graph.Window.window.visible
    /** The icons only move with full animations. */
    readonly property real iconClock: animations === "full" ? clock : 0

    /**
     * The side of a node. It shrinks with the graph, and on a short graph as far as it takes for the
     * text under the panels and the grid to stay clear of the battery and the house.
     */
    readonly property real nodeSide: Math.round(Math.max(smallestNode, Math.min(104, width / 5.2, height / 5.4, (height - padY * 2 - topCaptionHeight - captionHeight - 4) / 2)))
    /** Below this the icons are no longer clear. */
    readonly property real smallestNode: 32
    /** The text under the panels and the grid: the power and what it is. */
    readonly property real topCaptionHeight: Math.ceil(textMetrics.height * 1.93) + 6
    /** The least height at which the nodes, at their smallest, keep clear of each other's texts. */
    readonly property real neededHeight: padY * 2 + smallestNode * 2 + topCaptionHeight + captionHeight + 4
    /**
     * The text under a node: the power and what it is. With a capacity to go by, the battery adds a
     * third line that tells how long it lasts; the room for it is kept even while there is nothing
     * to tell, so that the nodes do not jump when the battery starts or stops.
     */
    readonly property real captionHeight: Math.ceil(textMetrics.height * (batteryCapacity !== null ? 2.71 : 1.93)) + 6
    /**
     * The widest text a node may get under it: the longest caption of the language, a power in kilowatts
     * or, with a capacity to go by, how long the battery lasts. Measured on hidden copies of the labels.
     */
    readonly property real captionWidth: Math.ceil(captionProbes.implicitWidth) + 6
    /** At the sides the margin leaves room for a caption wider than its node. */
    readonly property real padX: Math.max(8, Math.ceil((captionWidth - nodeSide) / 2))
    readonly property real padY: 8
    readonly property real cornerRadius: nodeSide * 0.22
    readonly property var plan: Layout.graphLayout(width, height, { node: nodeSide, caption: captionHeight, padX: padX, padY: padY, gap: 5 })

    readonly property real solarStrength: Flow.intensity(flow.solar.power, referencePower)
    readonly property real gridStrength: Flow.intensity(flow.grid.power, referencePower)
    readonly property real batteryStrength: Flow.intensity(flow.battery.power, referencePower)
    readonly property real loadStrength: Flow.intensity(flow.load.power, referencePower)
    readonly property bool batteryLow: flow.battery.soc !== null && flow.battery.soc < lowBattery
    /** batteryTime() of code/battery.mjs: how long the battery lasts or takes to fill, null when that cannot be told. */
    readonly property var batteryLeft: Battery.batteryTime({
        soc: flow.battery.soc,
        power: flow.battery.power,
        direction: flow.battery.direction,
        capacity: batteryCapacity,
        reserve: batteryReserve,
    })

    /**
     * Pixels a dot runs in a second, in step with the size of the graph, so that a trip takes the same
     * time on a small widget and on a big one: about four and a half seconds.
     */
    readonly property real dotSpeed: nodeSide * 0.7

    function dotCount(strength: real): int {
        return animations === "full" ? 1 + Math.round(strength * 2) : 1;
    }

    function tint(colour: string, active: bool): string {
        return active ? colour : scheme.idle;
    }

    FontMetrics {
        id: textMetrics

        font.family: graph.typography.family
        font.pointSize: graph.typography.size
    }

    // Hidden copies of the lines under a node, in the sizes `FlowNode` gives them. Plasma draws text hinted,
    // a little wider than FontMetrics reckons, so the labels themselves are measured.
    Column {
        id: captionProbes

        opacity: 0

        Components.Label {
            typography: graph.typography
            relativeSize: 1.08
            font.weight: Font.DemiBold
            text: "88,88 kW"
        }

        Repeater {
            model: ["node.solar", "node.grid", "node.battery", "node.load", "node.inverter", "grid.import", "grid.export", "battery.charge", "battery.discharge"]

            Components.Label {
                required property string modelData

                typography: graph.typography
                relativeSize: 0.85
                text: I18n.t(graph.language, modelData)
            }
        }

        Components.Label {
            visible: graph.batteryCapacity !== null
            typography: graph.typography
            relativeSize: 0.78
            text: I18n.t(graph.language, "battery.untilFull", { time: "8 h 88 min" })
        }
    }

    // Thirty steps a second are smooth for dots this slow, and cost the same on a 60 Hz screen and on a
    // 144 Hz one; an animation would move everything with every frame the screen draws.
    Timer {
        /** When the clock was last moved on, in milliseconds since 1970; 0 right after a standstill. */
        property real steppedAt: 0

        interval: 33
        repeat: true
        running: graph.moving

        onRunningChanged: steppedAt = 0
        onTriggered: {
            const now = Date.now();

            // Real time, not a count of steps: a late step must not slow the dots down.
            if (steppedAt > 0) {
                graph.clock += Math.min(0.25, (now - steppedAt) / 1000);
            }

            steppedAt = now;
        }
    }

    FlowLines {
        anchors.fill: parent
        links: graph.plan.links
        flow: graph.flow
        colours: graph.colours
        idleColour: graph.scheme.track
        cornerRadius: graph.cornerRadius
    }

    FlowDots {
        points: graph.plan.links.solar
        cornerRadius: graph.cornerRadius
        colour: graph.colours.solar
        direction: graph.flow.solar.direction
        speed: graph.dotSpeed
        count: graph.dotCount(graph.solarStrength)
        clock: graph.clock
        still: graph.animations === "off"
    }

    FlowDots {
        points: graph.plan.links.grid
        cornerRadius: graph.cornerRadius
        colour: graph.colours.grid
        direction: graph.flow.grid.direction
        speed: graph.dotSpeed
        count: graph.dotCount(graph.gridStrength)
        clock: graph.clock
        still: graph.animations === "off"
    }

    FlowDots {
        points: graph.plan.links.battery
        cornerRadius: graph.cornerRadius
        colour: graph.colours.battery
        direction: graph.flow.battery.direction
        speed: graph.dotSpeed
        count: graph.dotCount(graph.batteryStrength)
        clock: graph.clock
        still: graph.animations === "off"
    }

    FlowDots {
        points: graph.plan.links.load
        cornerRadius: graph.cornerRadius
        colour: graph.colours.load
        direction: graph.flow.load.direction
        speed: graph.dotSpeed
        count: graph.dotCount(graph.loadStrength)
        clock: graph.clock
        still: graph.animations === "off"
    }

    FlowNode {
        x: graph.plan.nodes.solar.x - width / 2
        y: graph.plan.nodes.solar.y - height / 2
        side: graph.nodeSide
        accent: graph.colours.solar
        active: graph.flow.solar.direction !== 0
        scheme: graph.scheme
        typography: graph.typography
        captionWidth: graph.captionWidth
        valueText: Format.power(graph.flow.solar.power, graph.powerUnit, graph.language)
        captionText: I18n.t(graph.language, "node.solar")

        Icons.SolarIcon {
            anchors.fill: parent
            tint: graph.tint(graph.colours.solar, graph.flow.solar.direction !== 0)
            active: graph.flow.solar.direction !== 0
            clock: graph.iconClock
            strength: graph.solarStrength
        }
    }

    FlowNode {
        x: graph.plan.nodes.grid.x - width / 2
        y: graph.plan.nodes.grid.y - height / 2
        side: graph.nodeSide
        accent: graph.colours.grid
        active: graph.flow.grid.direction !== 0
        scheme: graph.scheme
        typography: graph.typography
        captionWidth: graph.captionWidth
        valueText: Format.power(graph.flow.grid.power, graph.powerUnit, graph.language)
        captionText: I18n.t(graph.language, graph.flow.grid.state === "idle" ? "node.grid" : `grid.${graph.flow.grid.state}`)

        Icons.GridIcon {
            anchors.fill: parent
            tint: graph.tint(graph.colours.grid, graph.flow.grid.direction !== 0)
            active: graph.flow.grid.direction !== 0
            clock: graph.iconClock
            exporting: graph.flow.grid.state === "export"
        }
    }

    FlowNode {
        x: graph.plan.nodes.battery.x - width / 2
        y: graph.plan.nodes.battery.y - height / 2
        side: graph.nodeSide
        accent: graph.batteryLow ? graph.warningColour : graph.colours.battery
        active: graph.flow.battery.direction !== 0
        scheme: graph.scheme
        typography: graph.typography
        captionWidth: graph.captionWidth
        valueText: Format.power(graph.flow.battery.power, graph.powerUnit, graph.language)
        // The word says which way the watts go; the arrow on the line says it too.
        captionText: I18n.t(graph.language, graph.flow.battery.state === "idle" ? "node.battery" : `battery.${graph.flow.battery.state}`)
        noteText: graph.batteryLeft !== null
            ? I18n.t(graph.language, graph.batteryLeft.state === "discharge" ? "battery.left" : "battery.untilFull", { time: Format.duration(graph.batteryLeft.hours) })
            : ""

        Icons.BatteryIcon {
            anchors.fill: parent
            tint: graph.tint(graph.colours.battery, graph.flow.battery.direction !== 0)
            // The charge is worth its colour even while the battery rests.
            levelColour: graph.batteryLow ? graph.warningColour : graph.colours.battery
            soc: graph.flow.battery.soc
            direction: graph.flow.battery.direction
            clock: graph.iconClock
            percentText: Format.percent(graph.flow.battery.soc)
            fontFamily: graph.typography.family
        }
    }

    FlowNode {
        x: graph.plan.nodes.load.x - width / 2
        y: graph.plan.nodes.load.y - height / 2
        side: graph.nodeSide
        accent: graph.colours.load
        active: graph.flow.load.direction !== 0
        scheme: graph.scheme
        typography: graph.typography
        captionWidth: graph.captionWidth
        valueText: Format.power(graph.flow.load.power, graph.powerUnit, graph.language)
        captionText: I18n.t(graph.language, "node.load")

        Icons.HomeIcon {
            anchors.fill: parent
            tint: graph.tint(graph.colours.load, graph.flow.load.direction !== 0)
            active: graph.flow.load.direction !== 0
            clock: graph.iconClock
            strength: graph.loadStrength
        }
    }

    FlowNode {
        x: graph.plan.nodes.inverter.x - width / 2
        y: graph.plan.nodes.inverter.y - height / 2
        side: graph.nodeSide
        accent: graph.scheme.text
        glow: 0.07
        active: graph.flow.busy
        scheme: graph.scheme
        typography: graph.typography
        captionWidth: graph.captionWidth
        captionText: I18n.t(graph.language, "node.inverter")

        Icons.InverterIcon {
            anchors.fill: parent
            tint: graph.flow.busy ? graph.scheme.text : graph.scheme.idle
            accent: graph.colours.solar
            busy: graph.flow.busy
            clock: graph.iconClock
        }
    }
}
