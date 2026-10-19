import test from 'node:test';
import assert from 'node:assert/strict';
import { graphLayout } from '../package/contents/code/layout.mjs';

const metrics = { node: 60, caption: 40, padX: 10, padY: 10, gap: 6 };
const layout = graphLayout(440, 400, metrics);
const OUTER = ['solar', 'grid', 'battery', 'load'];

test('the panels and the grid sit on top, the battery and the house at the bottom', () => {
    assert.equal(layout.nodes.solar.y, layout.nodes.grid.y);
    assert.equal(layout.nodes.battery.y, layout.nodes.load.y);
    assert.ok(layout.nodes.solar.y < layout.nodes.battery.y);
});

test('the left and the right column mirror each other around the inverter', () => {
    assert.equal(layout.nodes.inverter.x, 220);
    assert.equal(layout.nodes.solar.x + layout.nodes.grid.x, 440);
    assert.equal(layout.nodes.battery.x + layout.nodes.load.x, 440);
});

test('the inverter sits halfway between the two rows', () => {
    assert.equal(layout.nodes.inverter.y, (layout.nodes.solar.y + layout.nodes.battery.y) / 2);
});

test('every node and its caption stay inside the padded area', () => {
    Object.keys(layout.nodes).forEach((id) => {
        const node = layout.nodes[id];

        assert.ok(node.x - metrics.node / 2 >= metrics.padX, `${id} left`);
        assert.ok(node.x + metrics.node / 2 <= 440 - metrics.padX, `${id} right`);
        assert.ok(node.y - metrics.node / 2 >= metrics.padY, `${id} top`);
        assert.ok(node.y + metrics.node / 2 + metrics.caption <= 400 - metrics.padY, `${id} bottom`);
    });
});

test('every line starts a gap away from its node and ends a gap away from the inverter', () => {
    OUTER.forEach((id) => {
        const points = layout.links[id];
        const first = points[0];
        const last = points[points.length - 1];

        assert.equal(Math.abs(first[0] - layout.nodes[id].x), metrics.node / 2 + metrics.gap, `${id} start`);
        assert.equal(first[1], layout.nodes[id].y, `${id} start height`);
        assert.equal(Math.abs(last[0] - layout.nodes.inverter.x), metrics.node / 2 + metrics.gap, `${id} end`);
    });
});

test('every line is made of horizontal and vertical runs only', () => {
    OUTER.forEach((id) => {
        const points = layout.links[id];

        for (let index = 1; index < points.length; index++) {
            const horizontal = points[index][1] === points[index - 1][1];
            const vertical = points[index][0] === points[index - 1][0];

            assert.ok(horizontal || vertical, `${id} run ${index}`);
        }
    });
});

test('the lines from the top enter the inverter above its middle, the ones from the bottom below it', () => {
    const entry = (id) => layout.links[id][layout.links[id].length - 1][1];

    assert.ok(entry('solar') < layout.nodes.inverter.y);
    assert.ok(entry('grid') < layout.nodes.inverter.y);
    assert.ok(entry('battery') > layout.nodes.inverter.y);
    assert.ok(entry('load') > layout.nodes.inverter.y);
    assert.equal(entry('solar'), entry('grid'));
});

test('a larger area spreads the nodes without resizing them', () => {
    const wide = graphLayout(880, 400, metrics);

    assert.equal(wide.nodes.solar.x, layout.nodes.solar.x);
    assert.equal(wide.nodes.grid.x, 880 - layout.nodes.solar.x);
});

test('the margin at the sides is set apart from the one above and below, for captions wider than their node', () => {
    const roomy = graphLayout(440, 400, { node: 60, caption: 40, padX: 34, padY: 8, gap: 6 });

    assert.deepEqual(roomy.nodes.solar, { x: 64, y: 38 });
    assert.deepEqual(roomy.nodes.load, { x: 376, y: 322 });
});
