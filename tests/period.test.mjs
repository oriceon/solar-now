import test from 'node:test';
import assert from 'node:assert/strict';
import { anchorFor, canGoForward, shiftAnchor, shiftDay } from '../package/contents/code/period.mjs';
import { barLabel, dayLabel, periodLabel } from '../package/contents/code/i18n.mjs';

test('a day moves by days, across the ends of months and years', () => {
    assert.equal(shiftDay('2026-10-13', -1), '2026-10-12');
    assert.equal(shiftDay('2026-03-01', -1), '2026-02-28');
    assert.equal(shiftDay('2026-12-31', 1), '2027-01-01');
});

test('the period a day belongs to depends on the scale', () => {
    assert.equal(anchorFor('month', '2026-10-13'), '2026-10');
    assert.equal(anchorFor('year', '2026-10-13'), '2026');
    assert.equal(anchorFor('total', '2026-10-13'), '2026');
});

test('a month moves by months and a year by years', () => {
    assert.equal(shiftAnchor('month', '2026-01', -1), '2025-12');
    assert.equal(shiftAnchor('month', '2026-12', 1), '2027-01');
    assert.equal(shiftAnchor('year', '2026', -1), '2025');
});

test('all the years are one period that does not move', () => {
    assert.equal(shiftAnchor('total', '2026', -1), '2026');
});

test('there is no going forward past the present', () => {
    assert.equal(canGoForward('month', '2026-10', '2026-10-13'), false);
    assert.equal(canGoForward('month', '2026-09', '2026-10-13'), true);
    assert.equal(canGoForward('year', '2025', '2026-10-13'), true);
    assert.equal(canGoForward('year', '2026', '2026-10-13'), false);
    assert.equal(canGoForward('total', '2026', '2026-10-13'), false);
    assert.equal(canGoForward('day', '2026-10-13', '2026-10-13'), false);
    assert.equal(canGoForward('day', '2026-10-12', '2026-10-13'), true);
});

test('a period is named in the language of the widget', () => {
    assert.equal(periodLabel('ro', 'month', '2026-10'), 'octombrie 2026');
    assert.equal(periodLabel('en', 'month', '2026-10'), 'October 2026');
    assert.equal(periodLabel('ro', 'year', '2026'), '2026');
    assert.equal(periodLabel('ro', 'total', '2026'), 'Toți anii');
});

test('today is called by its name, any other day by its date', () => {
    assert.equal(dayLabel('ro', '2026-10-13', '2026-10-13'), 'Azi');
    assert.equal(dayLabel('ro', '2026-10-12', '2026-10-13'), '12 octombrie 2026');
    assert.equal(dayLabel('en', '2026-10-12', '2026-10-13'), '12 October 2026');
});

test('a bar is labelled by its day, its month or its year', () => {
    assert.equal(barLabel('ro', 'month', 13), '13');
    assert.equal(barLabel('ro', 'year', 10), 'oct.');
    assert.equal(barLabel('en', 'year', 10), 'Oct');
    assert.equal(barLabel('ro', 'total', 2026), '2026');
});
