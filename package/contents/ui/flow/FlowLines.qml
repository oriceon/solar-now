import QtQuick

import "../../code/flowpath.mjs" as FlowPath

/**
 * The dashed lines between the nodes and the inverter, with an arrowhead where the power arrives.
 * Painted once per change; what moves along them are the dots of FlowDots.
 */
Canvas {
    id: lines

    /** Corner points of every line by id, see graphLayout() in code/layout.mjs. */
    required property var links
    /** buildFlow() of code/flow.mjs. */
    required property var flow
    /** Colour of every line by id, as text. */
    required property var colours
    /** Colour of a line nothing flows through, as text. */
    required property string idleColour
    required property real cornerRadius

    readonly property var ids: ["solar", "grid", "battery", "load"]
    /** Everything the picture depends on; a change of it repaints. */
    readonly property string signature: JSON.stringify([links, ids.map(id => flow[id].direction), ids.map(id => colours[id]), idleColour, cornerRadius])

    function trace(context: var, points: var): void {
        const commands = FlowPath.pathCommands(points, cornerRadius);

        context.beginPath();

        for (let index = 0; index < commands.length; index++) {
            const command = commands[index];

            if (command[0] === "M") {
                context.moveTo(command[1], command[2]);
            } else if (command[0] === "L") {
                context.lineTo(command[1], command[2]);
            } else {
                context.quadraticCurveTo(command[1], command[2], command[3], command[4]);
            }
        }
    }

    onPaint: {
        const context = getContext("2d");

        context.reset();
        context.clearRect(0, 0, width, height);
        context.lineCap = "round";
        context.lineJoin = "round";
        context.lineWidth = 1.6;

        for (let index = 0; index < ids.length; index++) {
            const id = ids[index];
            const way = flow[id].direction;
            const head = FlowPath.arrow(links[id], way);

            context.strokeStyle = way === 0 ? idleColour : colours[id];
            context.globalAlpha = way === 0 ? 1 : 0.7;
            context.setLineDash([2.4, 2.6]);
            trace(context, links[id]);
            context.stroke();

            if (head !== null) {
                context.save();
                context.setLineDash([]);
                context.globalAlpha = 1;
                context.fillStyle = colours[id];
                context.translate(head.x, head.y);
                context.rotate(head.angle * Math.PI / 180);
                context.beginPath();
                context.moveTo(2, 0);
                context.lineTo(-6.5, -4.5);
                context.lineTo(-6.5, 4.5);
                context.closePath();
                context.fill();
                context.restore();
            }
        }
    }
    onSignatureChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
