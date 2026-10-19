import test from 'node:test';
import assert from 'node:assert/strict';
import { batteryTime } from '../package/contents/code/battery.mjs';
import { duration } from '../package/contents/code/format.mjs';

const battery = { soc: 47, capacity: 32.9, reserve: 20 };
const time = (reading) => batteryTime(Object.assign({}, battery, reading));
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 0.01, `${actual} is not ${expected}`);

test('a discharging battery lasts as long as what is above its reserve, at the power drawn now', () => {
    const left = time({ power: 927, direction: 1 });

    assert.equal(left.state, 'discharge');
    // 27 % of 32.9 kWh at 0.927 kW.
    near(left.hours, 9.58);
});

test('a charging battery is full when what is missing has come in, at the power going in now', () => {
    const left = time({ power: 2000, direction: -1 });

    assert.equal(left.state, 'charge');
    // 53 % of 32.9 kWh at 2 kW.
    near(left.hours, 8.72);
});

test('a battery at or under its reserve has no time left', () => {
    assert.deepEqual(time({ soc: 20, power: 500, direction: 1 }), { state: 'discharge', hours: 0 });
    assert.deepEqual(time({ soc: 12, power: 500, direction: 1 }), { state: 'discharge', hours: 0 });
});

test('a full battery that still takes a trickle is not counted down', () => {
    assert.deepEqual(time({ soc: 100, power: 40, direction: -1 }), { state: 'charge', hours: 0 });
});

test('a resting battery has no estimate', () => {
    assert.equal(time({ power: 0, direction: 0 }), null);
});

test('without a capacity, a charge or a power there is no estimate', () => {
    assert.equal(time({ power: 500, direction: 1, capacity: null }), null);
    assert.equal(time({ power: 500, direction: 1, soc: null }), null);
    assert.equal(time({ power: null, direction: 1 }), null);
});

test('a duration under an hour is told in minutes', () => {
    assert.equal(duration(0.75), '45 min');
    assert.equal(duration(0), '0 min');
});

test('a duration of a few hours is told in hours and minutes', () => {
    assert.equal(duration(3.34), '3 h 20 min');
    assert.equal(duration(2), '2 h');
});

test('minutes that round up to an hour become one', () => {
    assert.equal(duration(1.999), '2 h');
});

test('a duration of ten hours or more is told in whole hours', () => {
    assert.equal(duration(12.4), '12 h');
});

test('a very long duration is capped, since nothing stays the same that long', () => {
    assert.equal(duration(250), '99 h+');
});

test('no duration shows a dash', () => {
    assert.equal(duration(null), '–');
});
