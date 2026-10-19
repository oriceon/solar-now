// The drawing of a line of the flow graph from its corner points.

function distance(from, to) {
    return Math.sqrt((to[0] - from[0]) * (to[0] - from[0]) + (to[1] - from[1]) * (to[1] - from[1]));
}

function tidy(value) {
    return Math.round(value * 100) / 100;
}

/** The point `length` away from `from`, on the way to `to`. */
function towards(from, to, length) {
    const share = length / distance(from, to);

    return [tidy(from[0] + (to[0] - from[0]) * share), tidy(from[1] + (to[1] - from[1]) * share)];
}

/**
 * The line through `points` (`[x, y]` pairs) with its corners rounded by at most `radius`, as drawing
 * commands: `['M', x, y]`, `['L', x, y]` and `['Q', controlX, controlY, x, y]`.
 */
export function pathCommands(points, radius) {
    if (points.length < 2) {
        return [];
    }

    const commands = [['M', points[0][0], points[0][1]]];

    for (let index = 1; index < points.length - 1; index++) {
        const corner = points[index];
        const cut = Math.min(radius, distance(points[index - 1], corner) / 2, distance(corner, points[index + 1]) / 2);

        if (cut <= 0) {
            commands.push(['L', corner[0], corner[1]]);
            continue;
        }

        const enter = towards(corner, points[index - 1], cut);
        const leave = towards(corner, points[index + 1], cut);

        commands.push(['L', enter[0], enter[1]], ['Q', corner[0], corner[1], leave[0], leave[1]]);
    }

    const last = points[points.length - 1];

    commands.push(['L', last[0], last[1]]);

    return commands;
}

/** The same line as an SVG path, for what follows it. */
export function roundedPath(points, radius) {
    return pathCommands(points, radius).map((command) => command.join(' ')).join(' ');
}

function angle(from, to) {
    const degrees = Math.round(Math.atan2(to[1] - from[1], to[0] - from[0]) * 180 / Math.PI);

    return (degrees + 360) % 360;
}

/**
 * Where the arrowhead of a line sits and which way it points, in degrees clockwise from "right".
 *
 * @param direction 1 when power runs along the points, -1 against them, 0 when nothing flows
 */
export function arrow(points, direction) {
    if (direction === 0 || points.length < 2) {
        return null;
    }

    const last = points.length - 1;
    const tip = direction > 0 ? points[last] : points[0];
    const before = direction > 0 ? points[last - 1] : points[1];

    return { x: tip[0], y: tip[1], angle: angle(before, tip) };
}
