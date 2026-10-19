import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { balance, daySeries, totals } from '../package/contents/code/chart.mjs';
import { parseAlerts, parseDay, parseFrames, parseHistory, parseLatest, parseMeasurePoints, parseStations, readResponse } from '../package/contents/code/deye.mjs';
import { buildFlow } from '../package/contents/code/flow.mjs';

// Answers of the real API, recorded with tools/capture.mjs on 2026-10-13 from a three-phase hybrid
// inverter with a battery, with everything personal taken out.
const data = (name) => readResponse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8')).data;

test('the real station reports the grid and the battery as signed readings only, which still tell the direction', () => {
    const latest = parseLatest(data('real-station-latest.json'));
    const flow = buildFlow(latest, {});

    assert.equal(latest.purchase, null);
    assert.equal(latest.feedIn, null);
    assert.deepEqual(flow.grid, { power: 12, direction: 1, state: 'import' });
    assert.deepEqual(flow.battery, { power: 927, direction: 1, state: 'discharge', soc: 47 });
    assert.deepEqual(flow.load, { power: 896, direction: -1 });
    assert.deepEqual(flow.solar, { power: 0, direction: 0 });
});

test('the real totals of the day are read', () => {
    assert.deepEqual(parseDay(data('real-station-day.json'), '2026-10-13'), { generation: 8.5, consumption: 18.7, feedIn: 0, purchase: 0.2, charge: 2.4, discharge: 12.4 });
});

test('the real curve of the day has a frame every five minutes, timed in seconds', () => {
    const frames = parseFrames(data('real-station-frames.json'));

    assert.ok(frames.length > 200);
    assert.equal(frames[1].time - frames[0].time, 300);
    assert.equal(frames[0].time, 1791839100);
});

test('the real curve gives a line for every quantity', () => {
    const series = daySeries(parseFrames(data('real-station-frames.json')), {});

    ['generation', 'consumption', 'grid', 'battery', 'soc'].forEach((name) => {
        assert.ok(series[name].length > 200, name);
    });
});

test('the two real halves of a month make one row per day', () => {
    const rows = parseHistory(data('real-station-month-1.json'), 'month', '2026-10').concat(parseHistory(data('real-station-month-2.json'), 'month', '2026-10'));

    assert.deepEqual(rows.map((row) => row.key), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
    assert.equal(rows[12].generation, 8.5);
});

test('the real months of the year come out in order, though the API sends them mixed up', () => {
    assert.deepEqual(parseHistory(data('real-station-year.json'), 'year', '2026').map((row) => row.key), [5, 6, 7, 8, 9, 10]);
});

test('of the ten years asked for, the real station has the one it has existed in', () => {
    assert.deepEqual(parseHistory(data('real-station-years.json'), 'total', '2026').map((row) => row.key), [2026]);
});

test('the real balance of the month adds up without a negative part', () => {
    const rows = parseHistory(data('real-station-month-1.json'), 'month', '2026-10');
    const result = balance(totals(rows));

    [result.consumption.solar, result.consumption.battery, result.consumption.grid, result.production.direct, result.production.charge, result.production.export].forEach((part) => {
        assert.ok(part >= 0);
    });
    assert.ok(result.selfSufficiency > 0.9);
});

test('the real inverter reports what goes to the backed-up loads apart from the whole consumption', () => {
    const inverter = parseMeasurePoints(data('real-device-latest.json')).filter((device) => device.type === 'INVERTER')[0];
    const value = (key) => inverter.points.filter((point) => point.key === key)[0];

    assert.equal(inverter.points.length, 101);
    assert.deepEqual(value('UPSLoadPower'), { key: 'UPSLoadPower', label: 'UPS Load Power', value: '891', unit: 'W' });
    assert.equal(value('TotalConsumptionPower').value, '896');
});

test('a real name that already has spaces is left as it is', () => {
    const inverter = parseMeasurePoints(data('real-device-latest.json')).filter((device) => device.type === 'INVERTER')[0];

    assert.ok(inverter.points.some((point) => point.label === 'Temperature- Battery'));
    assert.ok(inverter.points.some((point) => point.label === 'AC Temperature'));
});

test('the real account has one station, and a month without alerts', () => {
    assert.equal(parseStations(data('real-station-list.json')).length, 1);
    assert.deepEqual(parseAlerts(data('real-station-alerts.json')), []);
});

/** The frame of the real curve at a given time of 2026-10-13 (UTC), read like the latest data. */
function realFrame(hoursAndMinutes) {
    const frames = parseFrames(data('real-station-frames.json'));

    return frames.filter((frame) => new Date(frame.time * 1000).toISOString().slice(11, 16) === hoursAndMinutes)[0];
}

// The real station sends the one-way readings with the sign of the total: chargePower comes as -404,
// not 404, and gridPower as -606. Subtracting them as sizes turned charging into discharging.
test('a battery the real station reports as charging is drawn as charging', () => {
    const frame = realFrame('08:50');

    assert.equal(frame.charge, -404);
    assert.deepEqual(buildFlow(frame, {}).battery, { power: 404, direction: -1, state: 'charge', soc: 55 });
});

test('power the real station sends to the grid is drawn as sold', () => {
    const frame = realFrame('10:10');

    assert.equal(frame.feedIn, -606);
    assert.deepEqual(buildFlow(frame, {}).grid, { power: 606, direction: -1, state: 'export', });
});

test('every frame of the real day in which the charge of the battery rose is drawn as charging', () => {
    const frames = parseFrames(data('real-station-frames.json'));
    const rising = frames.filter((frame, index) => index > 0 && frame.soc > frames[index - 1].soc);

    assert.ok(rising.length > 0);
    rising.forEach((frame) => {
        assert.equal(buildFlow(frame, {}).battery.state, 'charge', new Date(frame.time * 1000).toISOString());
    });
});

test('on the real curve a charging battery is below zero, as on the Deye Cloud site', () => {
    const series = daySeries(parseFrames(data('real-station-frames.json')), {});
    const at = (time) => series.battery.filter((point) => point[0] === time)[0][1];

    assert.equal(at(realFrame('08:50').time), -404);
    assert.equal(at(realFrame('10:10').time), 660);
});
