// The clocks of Romania change on 2026-03-29 and on 2026-10-25; the computer of the user follows them.
process.env.TZ = 'Europe/Bucharest';

const { default: test } = await import('node:test');
const { default: assert } = await import('node:assert/strict');
const { dayBounds, hourMark } = await import('../package/contents/code/period.mjs');

test('an ordinary day lasts 24 hours, from midnight to midnight', () => {
    const { start, end } = dayBounds('2026-10-13');

    assert.equal(end - start, 24 * 3600);
    assert.equal(new Date(start * 1000).getHours(), 0);
});

test('the day the clocks go back lasts 25 hours', () => {
    const { start, end } = dayBounds('2026-10-25');

    assert.equal(end - start, 25 * 3600);
});

test('the day the clocks go forward lasts 23 hours', () => {
    const { start, end } = dayBounds('2026-03-29');

    assert.equal(end - start, 23 * 3600);
});

test('an hour mark sits at that time on the clock, even on a day with an hour more', () => {
    const { start } = dayBounds('2026-10-25');

    assert.equal(hourMark('2026-10-25', 12) - start, 13 * 3600);
    assert.equal(hourMark('2026-10-25', 24), dayBounds('2026-10-26').start);
});
