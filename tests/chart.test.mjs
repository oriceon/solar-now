import test from 'node:test';
import assert from 'node:assert/strict';
import { balance, dayPeaks, daySeries, money, nearestIndex, niceScale, shares, stacks, stackExtent, totals } from '../package/contents/code/chart.mjs';

/** The month of the reference screenshot of the Deye Cloud app. */
const october = { generation: 592.28, consumption: 245.19, feedIn: 333.2, purchase: 2.39, charge: 138.49, discharge: 122.2 };
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 0.005, `${actual} is not ${expected}`);

test('a scale ends on round numbers that hold the values', () => {
    assert.deepEqual(niceScale(0, 4.2, 5), { min: 0, max: 5, step: 1, ticks: [0, 1, 2, 3, 4, 5] });
});

test('a scale that spans both signs passes through zero', () => {
    assert.deepEqual(niceScale(-3.1, 7.4, 5), { min: -5, max: 7.5, step: 2.5, ticks: [-5, -2.5, 0, 2.5, 5, 7.5] });
});

test('a step of two and a half is taken where one of five would leave half the chart empty', () => {
    const scale = niceScale(-60, 60, 5);

    assert.equal(scale.step, 25);
    assert.deepEqual([scale.min, scale.max], [-75, 75]);
});

test('small steps do not pick up rounding noise', () => {
    assert.deepEqual(niceScale(0, 0.37, 5).ticks, [0, 0.1, 0.2, 0.3, 0.4]);
});

test('a scale without a span still has room', () => {
    assert.deepEqual(niceScale(0, 0, 5), { min: 0, max: 1, step: 0.2, ticks: [0, 0.2, 0.4, 0.6, 0.8, 1] });
});

test('totals add up every quantity over the rows, skipping what is missing', () => {
    const rows = [
        { key: 1, generation: 10, consumption: 4, feedIn: 5, purchase: 0, charge: 1, discharge: null },
        { key: 2, generation: 2.5, consumption: null, feedIn: 1, purchase: 0.5, charge: 0, discharge: null },
    ];

    assert.deepEqual(totals(rows), { generation: 12.5, consumption: 4, feedIn: 6, purchase: 0.5, charge: 1, discharge: null });
});

test('consumption is split into what came from the panels, the battery and the grid', () => {
    const { consumption } = balance(october);

    assert.equal(consumption.total, 245.19);
    near(consumption.solar, 120.6);
    assert.equal(consumption.battery, 122.2);
    assert.equal(consumption.grid, 2.39);
});

test('production is split into what was used directly, stored and sold', () => {
    const { production } = balance(october);

    assert.equal(production.total, 592.28);
    near(production.direct, 120.59);
    assert.equal(production.charge, 138.49);
    assert.equal(production.export, 333.2);
});

test('self-sufficiency is the share of consumption that did not come from the grid', () => {
    near(balance(october).selfSufficiency, 0.9903);
});

test('self-consumption is the share of production that was not sold', () => {
    near(balance(october).selfConsumption, 0.4374);
});

test('a part can not go below nothing when the readings do not add up', () => {
    const odd = balance({ generation: 1, consumption: 2, feedIn: 3, purchase: 4, charge: 5, discharge: 6 });

    assert.equal(odd.consumption.solar, 0);
    assert.equal(odd.production.direct, 0);
});

test('without consumption or production there is no share to speak of', () => {
    const none = balance({ generation: 0, consumption: null, feedIn: 0, purchase: 0, charge: 0, discharge: 0 });

    assert.equal(none.selfSufficiency, null);
    assert.equal(none.selfConsumption, null);
});

test('shares follow one another around the ring, without the empty ones', () => {
    assert.deepEqual(shares([{ key: 'a', value: 1 }, { key: 'b', value: 3 }, { key: 'c', value: 0 }, { key: 'd', value: null }]), [
        { key: 'a', value: 1, share: 0.25, from: 0, to: 0.25 },
        { key: 'b', value: 3, share: 0.75, from: 0.25, to: 1 },
    ]);
});

test('nothing to share gives no ring', () => {
    assert.deepEqual(shares([{ key: 'a', value: 0 }, { key: 'b', value: null }]), []);
});

test('sources are stacked upwards from zero and uses downwards', () => {
    const [bar] = stacks([{ key: 7, generation: 10, discharge: 2, purchase: 1, consumption: 5, charge: 3, feedIn: 5 }], ['generation', 'discharge', 'purchase'], ['consumption', 'charge', 'feedIn']);

    assert.equal(bar.key, 7);
    assert.deepEqual(bar.up, [{ key: 'generation', from: 0, to: 10 }, { key: 'discharge', from: 10, to: 12 }, { key: 'purchase', from: 12, to: 13 }]);
    assert.deepEqual(bar.down, [{ key: 'consumption', from: 0, to: -5 }, { key: 'charge', from: -5, to: -8 }, { key: 'feedIn', from: -8, to: -13 }]);
});

test('a missing or empty quantity leaves no slice in a stack', () => {
    const [bar] = stacks([{ key: 1, generation: null, discharge: 0, purchase: 4, consumption: 4, charge: null, feedIn: 0 }], ['generation', 'discharge', 'purchase'], ['consumption', 'charge', 'feedIn']);

    assert.deepEqual(bar.up, [{ key: 'purchase', from: 0, to: 4 }]);
    assert.deepEqual(bar.down, [{ key: 'consumption', from: 0, to: -4 }]);
});

test('the extent of the stacks is their highest top and lowest bottom', () => {
    const bars = stacks([{ key: 1, generation: 10, consumption: 4 }, { key: 2, generation: 3, consumption: 12 }], ['generation'], ['consumption']);

    assert.deepEqual(stackExtent(bars), { low: -12, high: 10 });
    assert.deepEqual(stackExtent([]), { low: 0, high: 0 });
});

test('the curve of a day has a line per quantity, with the grid and the battery signed', () => {
    const series = daySeries([
        { time: 0, generation: 100, consumption: 300, purchase: 200, feedIn: 0, wire: 200, charge: 0, discharge: 0, battery: 0, soc: 50 },
        { time: 300, generation: 900, consumption: 300, purchase: 0, feedIn: 100, wire: -100, charge: 500, discharge: 0, battery: -500, soc: 51 },
    ], {});

    assert.deepEqual(series.generation, [[0, 100], [300, 900]]);
    assert.deepEqual(series.consumption, [[0, 300], [300, 300]]);
    assert.deepEqual(series.grid, [[0, 200], [300, -100]]);
    assert.deepEqual(series.battery, [[0, 0], [300, -500]]);
    assert.deepEqual(series.soc, [[0, 50], [300, 51]]);
});

test('a frame without a reading leaves a gap in that line only', () => {
    const series = daySeries([{ time: 0, generation: null, consumption: 5, soc: null }, { time: 300, generation: 7, consumption: 6, soc: 40 }], {});

    assert.deepEqual(series.generation, [[300, 7]]);
    assert.deepEqual(series.consumption, [[0, 5], [300, 6]]);
});

test('the frame nearest to a moment is found, whichever side it is on', () => {
    const frames = [{ time: 0 }, { time: 300 }, { time: 600 }];

    assert.equal(nearestIndex(frames, 140), 0);
    assert.equal(nearestIndex(frames, 160), 1);
    assert.equal(nearestIndex(frames, 9999), 2);
    assert.equal(nearestIndex([], 5), -1);
});

test('money: what was not bought is saved, what was sold is earned, what was bought is paid', () => {
    assert.deepEqual(money(october, { buy: 1.3, sell: 0.5 }), { saved: 315.64, earned: 166.6, paid: 3.11, benefit: 482.24 });
});

test('money: without a price there is nothing to show', () => {
    assert.equal(money(october, { buy: 0, sell: 0 }), null);
});

test('money: with one price only, the other amount is nothing rather than unknown', () => {
    assert.deepEqual(money(october, { buy: 0, sell: 0.5 }), { saved: 0, earned: 166.6, paid: 0, benefit: 166.6 });
});

test('money: readings that are missing count as nothing', () => {
    assert.deepEqual(money({ generation: null, consumption: 10, feedIn: null, purchase: null, charge: null, discharge: null }, { buy: 2, sell: 1 }), { saved: 20, earned: 0, paid: 0, benefit: 20 });
});

test('the peaks of a day are its highest production and its highest consumption, each with its time', () => {
    const peaks = dayPeaks([
        { time: 0, generation: 100, consumption: 900 },
        { time: 300, generation: 4120, consumption: 300 },
        { time: 600, generation: 800, consumption: 3400 },
    ]);

    assert.deepEqual(peaks, { generation: { value: 4120, time: 300 }, consumption: { value: 3400, time: 600 } });
});

test('a day without any production has no peak of it', () => {
    const peaks = dayPeaks([{ time: 0, generation: 0, consumption: 500 }, { time: 300, generation: null, consumption: null }]);

    assert.equal(peaks.generation, null);
    assert.deepEqual(peaks.consumption, { value: 500, time: 0 });
});
