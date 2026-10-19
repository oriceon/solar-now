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
