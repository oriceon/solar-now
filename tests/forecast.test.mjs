import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseDailyGeneration, readResponse, recentDaysRequest } from '../package/contents/code/deye.mjs';
import { estimateState, expectedProduction, parseRadiation, radiationUrl, retryMinutes } from '../package/contents/code/forecast.mjs';

const text = (name) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
// Recorded from Open-Meteo on 2026-10-13, for made-up coordinates.
const radiation = parseRadiation(JSON.parse(text('openmeteo-radiation.json')));

test('the radiation is asked for at the place of the station, rounded so that it does not tell the house', () => {
    assert.equal(
        radiationUrl('https://api.open-meteo.com/', 44.18073, 28.63432),
        'https://api.open-meteo.com/v1/forecast?latitude=44.18&longitude=28.63&daily=shortwave_radiation_sum&timezone=auto&past_days=14&forecast_days=2',
    );
});

test('the radiation of every day is read by its date', () => {
    assert.equal(Object.keys(radiation).length, 16);
    assert.equal(radiation['2026-10-13'], 1.91);
    assert.equal(radiation['2026-10-14'], 2.91);
});

test('an answer without days gives no radiation', () => {
    assert.deepEqual(parseRadiation({}), {});
    assert.deepEqual(parseRadiation({ daily: { time: ['2026-10-13'], shortwave_radiation_sum: [null] } }), {});
});

test('the last two weeks are asked for day by day, up to but without today', () => {
    assert.deepEqual(recentDaysRequest('eu', '', '61000001', '2026-10-13').body, { stationId: 61000001, granularity: 2, startAt: '2026-09-29', endAt: '2026-10-13' });
});

test('the production of every day is read with its date', () => {
    const days = parseDailyGeneration(readResponse(text('real-station-month-1.json')).data);

    assert.equal(days.length, 13);
    assert.deepEqual(days[12], { date: '2026-10-13', generation: 8.5 });
    assert.equal(days[0].date, '2026-10-01');
});

test('tomorrow is expected to give what the same radiation has given lately', () => {
    // Every day produced 3 kWh per MJ/m².
    const days = ['2026-10-09', '2026-10-10', '2026-10-11', '2026-10-12'].map((date) => ({ date: date, generation: radiation[date] * 3 }));

    assert.deepEqual(expectedProduction(days, radiation, '2026-10-14'), { kwh: 8.7, days: 4 });
});

test('one odd day does not pull the estimate after it', () => {
    const days = [
        { date: '2026-10-08', generation: radiation['2026-10-08'] * 3 },
        { date: '2026-10-09', generation: radiation['2026-10-09'] * 3 },
        { date: '2026-10-10', generation: radiation['2026-10-10'] * 3 },
        // A day the inverter was mostly switched off.
        { date: '2026-10-11', generation: 0.4 },
        { date: '2026-10-12', generation: radiation['2026-10-12'] * 3 },
    ];

    assert.equal(expectedProduction(days, radiation, '2026-10-14').kwh, 8.7);
});

test('days without production, without radiation or with next to no sun are not learned from', () => {
    const days = [
        { date: '2026-10-10', generation: null },
        { date: '2026-10-11', generation: 0 },
        { date: '2026-10-12', generation: 40 },
        { date: '2026-09-01', generation: 40 },
    ];

    assert.equal(expectedProduction(days, radiation, '2026-10-14'), null);
});

test('fewer than three days to learn from give no estimate', () => {
    const days = ['2026-10-11', '2026-10-12'].map((date) => ({ date: date, generation: radiation[date] * 3 }));

    assert.equal(expectedProduction(days, radiation, '2026-10-14'), null);
});

test('a day without a forecast of radiation has no estimate', () => {
    const days = ['2026-10-09', '2026-10-10', '2026-10-11', '2026-10-12'].map((date) => ({ date: date, generation: radiation[date] * 3 }));

    assert.equal(expectedProduction(days, radiation, '2026-10-20'), null);
});

const place = { id: '1', latitude: 44.18, longitude: 28.63 };

test('a turned off estimate is neither shown nor asked for', () => {
    assert.equal(estimateState(false, undefined, null, undefined), 'off');
});

// On a widget set up a moment ago, nothing has been asked for yet: the estimate is on its way, not missing.
test('an estimate not asked for yet, or failed, is waiting to be asked for', () => {
    assert.equal(estimateState(true, undefined, null, undefined), 'waiting');
    assert.equal(estimateState(true, { status: 'failed', data: null }, null, undefined), 'waiting');
    assert.equal(estimateState(true, { status: 'ready', data: [place] }, place, undefined), 'waiting');
    assert.equal(estimateState(true, { status: 'ready', data: [place] }, place, { status: 'failed', data: null }), 'waiting');
});

test('an estimate whose stations or radiation are on their way is loading', () => {
    assert.equal(estimateState(true, { status: 'loading', data: null }, null, undefined), 'loading');
    assert.equal(estimateState(true, { status: 'ready', data: [place] }, place, { status: 'loading', data: null }), 'loading');
});

test('an estimate on hand stays shown while it is asked for again, and after that fails', () => {
    assert.equal(estimateState(true, { status: 'ready', data: [place] }, place, { status: 'loading', data: {} }), 'ready');
    assert.equal(estimateState(true, { status: 'ready', data: [place] }, place, { status: 'failed', data: {} }), 'ready');
});

test('a station listed without its place has no estimate', () => {
    assert.equal(estimateState(true, { status: 'ready', data: [] }, null, undefined), 'none');
});

test('a failed estimate is asked for again after one, two and four minutes, then with the refreshes of the live data', () => {
    assert.deepEqual([0, 1, 2, 3].map(retryMinutes), [1, 2, 4, null]);
});
