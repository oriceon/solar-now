pragma ComponentBehavior: Bound

import QtQuick

import "../../code/flowpath.mjs" as FlowPath

/** The glowing dots that run along a line of the graph, the way the power flows. */
Item {
    id: dots

    /** Corner points of the line, from its node to the inverter. */
    required property var points
    required property real cornerRadius
    required property color colour
    /** 1 towards the inverter, -1 away from it, 0 for a line nothing flows through. */
    required property int direction
    /**
     * Pixels a dot runs in a second. The same on every line, whatever flows through it: how much flows
     * is told by how many dots there are.
     */
    required property real speed
    /** Seconds the graph has been animating. */
    required property real clock
    /** True for a picture that does not move: the dots then rest spread along the line. */
    required property bool still
    property int count: 1
    property real size: 7

    readonly property string svg: FlowPath.roundedPath(points, cornerRadius)
    /** Length of the line, corners taken square. */
    readonly property real length: {
        let total = 0;

        for (let index = 1; index < points.length; index++) {
            total += Math.hypot(points[index][0] - points[index - 1][0], points[index][1] - points[index - 1][1]);
        }

        return total;
    }
    /** Trips along the line per second. */
    readonly property real pace: length > 0 ? speed / length : 0

    visible: direction !== 0

    Repeater {
        model: dots.visible ? dots.count : 0

        delegate: Item {
            id: dot

            required property int index

            /** How far along its trip the dot is, 0…1. */
            readonly property real along: dots.still ? (index + 0.5) / dots.count : (dots.clock * dots.pace + index / dots.count) % 1

            x: place.x
            y: place.y
            // A dot fades in as it leaves and out as it arrives.
            opacity: dots.still ? 1 : Math.min(1, along / 0.1, (1 - along) / 0.1)

            PathInterpolator {
                id: place

                progress: dots.direction > 0 ? dot.along : 1 - dot.along

                path: Path {
                    PathSvg {
                        path: dots.svg
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dots.size * 2.6
                height: width
                radius: width / 2
                color: dots.colour
                opacity: 0.22
            }

            Rectangle {
                anchors.centerIn: parent
                width: dots.size
                height: width
                radius: width / 2
                color: Qt.lighter(dots.colour, 1.25)
            }
        }
    }
}
