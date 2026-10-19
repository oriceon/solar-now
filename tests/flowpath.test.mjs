import test from 'node:test';
import assert from 'node:assert/strict';
import { arrow, pathCommands, roundedPath } from '../package/contents/code/flowpath.mjs';

const elbow = [[0, 0], [10, 0], [10, 10]];
const line = [[20, 100], [80, 100], [80, 160], [140, 160]];

test('two points make a straight line', () => {
    assert.equal(roundedPath([[0, 0], [10, 0]], 4), 'M 0 0 L 10 0');
});

test('a corner is cut short on both sides and rounded through its point', () => {
    assert.equal(roundedPath(elbow, 4), 'M 0 0 L 6 0 Q 10 0 10 4 L 10 10');
});

test('the rounding never takes more than half of the shorter run', () => {
    assert.equal(roundedPath(elbow, 50), 'M 0 0 L 5 0 Q 10 0 10 5 L 10 10');
});

test('no radius leaves the corners sharp', () => {
    assert.equal(roundedPath(elbow, 0), 'M 0 0 L 10 0 L 10 10');
});

test('every corner of a longer line is rounded', () => {
    assert.equal(roundedPath(line, 10), 'M 20 100 L 70 100 Q 80 100 80 110 L 80 150 Q 80 160 90 160 L 140 160');
});

test('fewer than two points draw nothing', () => {
    assert.equal(roundedPath([[1, 1]], 4), '');
    assert.equal(roundedPath([], 4), '');
});

test('power flowing along the line is marked by an arrow at its end, pointing the way it runs', () => {
    assert.deepEqual(arrow(line, 1), { x: 140, y: 160, angle: 0 });
    assert.deepEqual(arrow(elbow, 1), { x: 10, y: 10, angle: 90 });
});

test('power flowing against the line is marked at its start, pointing back', () => {
    assert.deepEqual(arrow(line, -1), { x: 20, y: 100, angle: 180 });
    assert.deepEqual(arrow([[0, 10], [0, 0]], -1), { x: 0, y: 10, angle: 90 });
});

test('a line nothing flows through has no arrow', () => {
    assert.equal(arrow(line, 0), null);
});

test('the same line is available as drawing commands, for a canvas', () => {
    assert.deepEqual(pathCommands(elbow, 4), [['M', 0, 0], ['L', 6, 0], ['Q', 10, 0, 10, 4], ['L', 10, 10]]);
});

test('the path and the drawing commands never disagree', () => {
    const fromCommands = pathCommands(line, 10).map((command) => command.join(' ')).join(' ');

    assert.equal(fromCommands, roundedPath(line, 10));
});
