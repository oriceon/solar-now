import test from 'node:test';
import assert from 'node:assert/strict';
import { REFRESH_CHOICES, needsLoading, refreshMinutes, worthRefreshing } from '../package/contents/code/cache.mjs';

const minute = 60 * 1000;
const now = 600 * minute;

test('an answer not on hand is asked for', () => {
    assert.equal(needsLoading(undefined, false, 10, now), true);
});

test('an answer about a period that was already over when it came is kept for good', () => {
    assert.equal(needsLoading({ status: 'ready', at: 0, current: false }, false, 10, now), false);
});

test('an answer about the present is asked for again once it is older than it may be', () => {
    assert.equal(needsLoading({ status: 'ready', at: now - 11 * minute, current: true }, true, 10, now), true);
    assert.equal(needsLoading({ status: 'ready', at: now - 5 * minute, current: true }, true, 10, now), false);
});

// A curve fetched at 23:50 would otherwise stop at 23:50 for the rest of the session.
test('an answer that came while its period was still going on is asked for again after that period is over', () => {
    assert.equal(needsLoading({ status: 'ready', at: now - 11 * minute, current: true }, false, 10, now), true);
});

test('a failed answer is asked for again', () => {
    assert.equal(needsLoading({ status: 'failed', at: now, current: false }, false, 10, now), true);
});

test('a request still on its way is not sent twice', () => {
    assert.equal(needsLoading({ status: 'loading', at: now - 10 * 1000, current: true }, true, 10, now), false);
});

// After a suspend, a request may never answer; it must not block its answer for the whole session.
test('a request that has not answered within a minute is given up and sent again', () => {
    assert.equal(needsLoading({ status: 'loading', at: now - 61 * 1000, current: true }, true, 10, now), true);
});

test('the data of a station is not asked for more often than Deye refreshes it, every 5 minutes', () => {
    assert.deepEqual(REFRESH_CHOICES, [5, 10, 15, 30]);
});

test('a refresh of 1 or 2 minutes kept from an older version counts as 5', () => {
    assert.equal(refreshMinutes(1), 5);
    assert.equal(refreshMinutes(2), 5);
    assert.equal(refreshMinutes(10), 10);
    assert.equal(refreshMinutes(undefined), 5);
});

test('a refresh by hand within a minute of the last answer asks for nothing', () => {
    assert.equal(worthRefreshing(now - 30 * 1000, now), false);
    assert.equal(worthRefreshing(now - minute, now), true);
});

test('a refresh by hand asks when nothing has come yet', () => {
    assert.equal(worthRefreshing(NaN, now), true);
    assert.equal(worthRefreshing(0, now), true);
});
