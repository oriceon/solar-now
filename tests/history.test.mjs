import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
    alertsRequest,
    deviceLatestRequest,
    devicesRequest,
    framesRequest,
    historyRequests,
    parseAlerts,
    parseDevices,
    parseFrames,
    parseHistory,
    parseMeasurePoints,
    readResponse,
} from '../package/contents/code/deye.mjs';

const data = (name) => readResponse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8')).data;
const body = (request) => request.body;

// Recorded from the real API on 2026-10-13: frames without an end are refused as "invalid param".
test('the curve of a day is asked for as frames from that day to that day', () => {
    assert.deepEqual(framesRequest('eu', '', '61000001', '2026-10-13'), {
        url: 'https://eu1-developer.deyecloud.com/v1.0/station/history',
        body: { stationId: 61000001, granularity: 1, startAt: '2026-10-13', endAt: '2026-10-13' },
    });
});

// Recorded from the real API: the end of a range of days is not counted, and 31 days are one too many.
test('a month is asked for day by day in two halves, since the API takes at most 30 days at once', () => {
    assert.deepEqual(historyRequests('eu', '', '1', 'month', '2026-10').map(body), [
        { stationId: 1, granularity: 2, startAt: '2026-10-01', endAt: '2026-10-16' },
        { stationId: 1, granularity: 2, startAt: '2026-10-16', endAt: '2026-11-01' },
    ]);
});

test('the second half of December ends with the first day of the next year', () => {
    assert.equal(body(historyRequests('eu', '', '1', 'month', '2026-12')[1]).endAt, '2027-01-01');
});

// Recorded from the real API: the end of a range of months and of years is counted.
test('a year is asked for month by month, from January to December', () => {
    assert.deepEqual(historyRequests('eu', '', '1', 'year', '2026').map(body), [{ stationId: 1, granularity: 3, startAt: '2026-01', endAt: '2026-12' }]);
});

test('all the years are asked for as the ten that end with the current one', () => {
    assert.deepEqual(historyRequests('eu', '', '1', 'total', '2026').map(body), [{ stationId: 1, granularity: 4, startAt: '2017', endAt: '2026' }]);
});

test('frames are read like the latest data, each with its time', () => {
    const frames = parseFrames(data('schema-station-frames.json'));

    assert.equal(frames.length, 228);
    assert.equal(frames[0].time, Date.UTC(2026, 9, 12, 21, 0) / 1000);
    assert.equal(frames[0].generation, 0);
    assert.equal(typeof frames[150].soc, 'number');
});

test('frames come out in the order of time, without the ones that have none', () => {
    const frames = parseFrames({ stationDataItems: [{ timeStamp: 300, generationPower: 2 }, { generationPower: 9 }, { timeStamp: 0, generationPower: 1 }] });

    assert.deepEqual(frames.map((frame) => frame.generation), [1, 2]);
});

test('the days of a month are read as rows of energy, one per day', () => {
    const rows = parseHistory(data('schema-station-month.json'), 'month', '2026-10');

    assert.equal(rows.length, 13);
    assert.deepEqual(rows[0], { key: 1, generation: 47.28, consumption: 18.58, feedIn: 26.63, purchase: 0.1, charge: 11, discharge: 9.29 });
    assert.equal(rows[12].key, 13);
});

test('the months of a year leave out a month of another year', () => {
    const rows = parseHistory(data('schema-station-year.json'), 'year', '2026');

    assert.deepEqual(rows.map((row) => row.key), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert.equal(rows[9].generation, 592.3);
});

test('of all the years, only those with any energy are kept, up to the current one', () => {
    const rows = parseHistory(data('schema-station-years.json'), 'total', '2026');

    assert.deepEqual(rows.map((row) => row.key), [2025, 2026]);
});

test('an answer without items gives no rows', () => {
    assert.deepEqual(parseHistory({}, 'month', '2026-10'), []);
    assert.deepEqual(parseFrames({}), []);
});

test('alerts are asked for by a range of seconds, as many at once as the API allows', () => {
    assert.deepEqual(alertsRequest('eu', '', '61000001', 1000, 2000), {
        url: 'https://eu1-developer.deyecloud.com/v1.0/station/alertList',
        body: { stationId: 61000001, startTimestamp: 1000, endTimestamp: 2000, page: 1, size: 200 },
    });
});

test('alerts come out newest first, with their level in words', () => {
    const alerts = parseAlerts(data('schema-station-alerts.json'));

    assert.deepEqual(alerts.map((alert) => alert.name), ['Grid mode changed', 'Heatsink temperature high', 'DC bus voltage low']);
    assert.deepEqual(alerts.map((alert) => alert.level), ['notice', 'failure', 'warning']);
});

test('an alert that is still open has no end', () => {
    const [open, closed] = parseAlerts(data('schema-station-alerts.json'));

    assert.equal(open.open, true);
    assert.equal(open.endedAt, null);
    assert.equal(closed.open, false);
    assert.equal(closed.endedAt - closed.startedAt, 600);
});

test('the devices of a station are asked for by its id, the data of a device by its serial number', () => {
    assert.deepEqual(body(devicesRequest('eu', '', '61000001')), { page: 1, size: 20, stationIds: [61000001] });
    assert.deepEqual(body(deviceLatestRequest('eu', '', ['SN0001'])), { deviceList: ['SN0001'] });
});

test('devices are listed with their kind', () => {
    assert.deepEqual(parseDevices(data('schema-station-devices.json')), [
        { serial: 'SN0001', type: 'INVERTER' },
        { serial: 'SN0002', type: 'COLLECTOR' },
    ]);
});

test('the measure points of a device keep their value and unit, and get a name that can be read', () => {
    const [inverter] = parseMeasurePoints(data('schema-device-latest.json'));

    assert.equal(inverter.serial, 'SN0001');
    assert.equal(inverter.collectedAt, Date.UTC(2026, 9, 13, 9, 0) / 1000);
    assert.deepEqual(inverter.points[0], { key: 'DCVoltagePV1', label: 'DC Voltage PV1', value: '312.40', unit: 'V' });
    assert.deepEqual(inverter.points[11], { key: 'UPSLoadPower', label: 'UPS Load Power', value: '761', unit: 'W' });
});

test('a measure point without a unit has an empty one', () => {
    const [inverter] = parseMeasurePoints(data('schema-device-latest.json'));

    assert.deepEqual(inverter.points[13], { key: 'WorkMode', label: 'Work Mode', value: 'Selling First', unit: '' });
});
