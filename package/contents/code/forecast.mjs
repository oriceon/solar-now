// What the panels may produce today and tomorrow, learned from the last two weeks: every day that
// has both the radiation of the sun and the production of the station tells how many kWh a MJ/m²
// brings here, whatever the size, the tilt and the shading of the panels.

/** A day with less sun than this (MJ/m²) says more about the weather than about the panels. */
const LEAST_RADIATION = 1;
/** Fewer days than this are not enough to learn from. */
const LEAST_DAYS = 3;

function known(value) {
    return value !== null && value !== undefined && !Number.isNaN(value);
}

/** The radiation of the last two weeks, today and tomorrow, at a place rounded to about a kilometre. */
export function radiationUrl(host, latitude, longitude) {
    const base = String(host).trim().replace(/\/+$/, '');

    return `${base}/v1/forecast?latitude=${latitude.toFixed(2)}&longitude=${longitude.toFixed(2)}&daily=shortwave_radiation_sum&timezone=auto&past_days=14&forecast_days=2`;
}

/** The radiation of every day in MJ/m², by its date (yyyy-MM-dd), from an answer of Open-Meteo. */
export function parseRadiation(json) {
    const daily = json.daily || {};
    const dates = daily.time || [];
    const sums = daily.shortwave_radiation_sum || [];
    const byDate = {};

    dates.forEach((date, index) => {
        if (known(sums[index])) {
            byDate[date] = sums[index];
        }
    });

    return byDate;
}

function median(values) {
    const sorted = values.slice().sort((small, large) => small - large);
    const middle = Math.floor(sorted.length / 2);

    return sorted.length % 2 === 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

/**
 * @param days      `{ date, generation }` of the last days, see parseDailyGeneration() in code/deye.mjs
 * @param radiation parseRadiation()
 * @param date      the day to estimate, yyyy-MM-dd
 * @returns `{ kwh, days }`: the production to expect and how many days it was learned from; null
 *          when there is too little to go by. The middle of what the days say is taken, so that a
 *          day the inverter was off, or the battery was full, does not pull the estimate after it.
 */
export function expectedProduction(days, radiation, date) {
    const yields = days
        .filter((day) => known(day.generation) && day.generation > 0 && known(radiation[day.date]) && radiation[day.date] >= LEAST_RADIATION)
        .map((day) => day.generation / radiation[day.date]);

    if (yields.length < LEAST_DAYS || !known(radiation[date])) {
        return null;
    }

    return { kwh: Number((median(yields) * radiation[date]).toFixed(1)), days: yields.length };
}

function asking(entry) {
    return entry !== undefined && entry !== null && entry.status === 'loading' ? 'loading' : 'waiting';
}

/**
 * Where the estimate stands, from what ArchiveStore has on hand.
 *
 * @param shown    whether the estimate is turned on
 * @param stations the entry of the stations of the account, `{ status, data }`; undefined while not asked for
 * @param place    the station on show as listed there, with its coordinates; null when not listed with them
 * @param answer   the entry of the estimate, likewise
 * @returns off; ready, with something on hand; loading, on its way; waiting, not asked for yet or failed;
 *          none, when the station is listed without its place and there is nothing to estimate for
 */
export function estimateState(shown, stations, place, answer) {
    if (!shown) {
        return 'off';
    }

    if (place === null) {
        return stations !== undefined && stations !== null && stations.data !== null ? 'none' : asking(stations);
    }

    return answer !== undefined && answer !== null && answer.data !== null ? 'ready' : asking(answer);
}

/** How many times in a row an estimate that failed is asked for again sooner than the live data is refreshed. */
const RETRIES = 3;

/**
 * Minutes after which an estimate that failed is asked for again: one, then two, then four. After
 * that it waits for the refreshes of the live data, so that a service that stays down is not asked
 * every minute.
 *
 * @param failures how many times in a row it failed before; null when it is not to be asked for sooner
 */
export function retryMinutes(failures) {
    return failures < RETRIES ? 2 ** failures : null;
}
