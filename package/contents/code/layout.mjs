// Where the nodes of the flow graph sit and how the lines between them run.

/** How far from the middle of the inverter a line enters it, as a share of the side of a node. */
const PORT_SHARE = 0.22;

/**
 * The panels and the grid on top, the battery and the house at the bottom, the inverter in the middle.
 *
 * @param metrics `{ node, caption, padX, padY, gap }`: side of a node, height of the text under it, margin
 *                at the sides and above and below the graph, distance between a node and the end of its line
 * @returns `{ nodes, links }`: centres of the nodes by id, and for every outer node the corner
 *          points of its line, from the node to the inverter
 */
export function graphLayout(width, height, metrics) {
    const half = metrics.node / 2;
    const reach = half + metrics.gap;
    const left = metrics.padX + half;
    const right = width - metrics.padX - half;
    const centre = width / 2;
    const top = metrics.padY + half;
    const bottom = height - metrics.padY - metrics.caption - half;
    const middle = (top + bottom) / 2;
    const port = metrics.node * PORT_SHARE;
    const turnLeft = left + (centre - left) / 2;
    const turnRight = right - (right - centre) / 2;

    return {
        nodes: {
            solar: { x: left, y: top },
            grid: { x: right, y: top },
            battery: { x: left, y: bottom },
            load: { x: right, y: bottom },
            inverter: { x: centre, y: middle },
        },
        links: {
            solar: [[left + reach, top], [turnLeft, top], [turnLeft, middle - port], [centre - reach, middle - port]],
            grid: [[right - reach, top], [turnRight, top], [turnRight, middle - port], [centre + reach, middle - port]],
            battery: [[left + reach, bottom], [turnLeft, bottom], [turnLeft, middle + port], [centre - reach, middle + port]],
            load: [[right - reach, bottom], [turnRight, bottom], [turnRight, middle + port], [centre + reach, middle + port]],
        },
    };
}
