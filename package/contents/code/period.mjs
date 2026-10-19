// Moving through days, months and years. Dates are text: yyyy-MM-dd, yyyy-MM or yyyy.

function twoDigits(value) {
    return `0${value}`.slice(-2);
}

export function shiftDay(date, days) {
    const parts = date.split('-').map(Number);
    const moved = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] + days));

    return `${moved.getUTCFullYear()}-${twoDigits(moved.getUTCMonth() + 1)}-${twoDigits(moved.getUTCDate())}`;
}

/** The period of `scale` the day `date` is in: its month for month, its year for year and for total. */
export function anchorFor(scale, date) {
    return scale === 'month' ? date.slice(0, 7) : date.slice(0, 4);
}

/** The period `steps` before or after; all the years together are one period, which does not move. */
export function shiftAnchor(scale, anchor, steps) {
    if (scale === 'month') {
        const moved = new Date(Date.UTC(Number(anchor.slice(0, 4)), Number(anchor.slice(5, 7)) - 1 + steps, 1));

        return `${moved.getUTCFullYear()}-${twoDigits(moved.getUTCMonth() + 1)}`;
    }

    return scale === 'year' ? String(Number(anchor) + steps) : anchor;
}

/** False for the period today is in, which is the last one there is; `scale` may also be day. */
export function canGoForward(scale, anchor, today) {
    if (scale === 'total') {
        return false;
    }

    return anchor < (scale === 'day' ? today : anchorFor(scale, today));
}

/**
 * When the day `date` (yyyy-MM-dd) starts and ends on the clock of the computer, in seconds since 1970.
 * Not always 24 hours apart: the day the clocks go back lasts 25, the day they go forward 23.
 */
export function dayBounds(date) {
    const parts = date.split('-').map(Number);

    return {
        start: new Date(parts[0], parts[1] - 1, parts[2]).getTime() / 1000,
        end: new Date(parts[0], parts[1] - 1, parts[2] + 1).getTime() / 1000,
    };
}

/** The moment the clock shows `hour`:00 on the day `date`, in seconds since 1970; hour 24 is the next midnight. */
export function hourMark(date, hour) {
    const parts = date.split('-').map(Number);

    return new Date(parts[0], parts[1] - 1, parts[2], hour).getTime() / 1000;
}
