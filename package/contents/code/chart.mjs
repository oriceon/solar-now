// The arithmetic behind the charts: scales, stacks, shares and the lines of a day.

import { batteryFlow, gridFlow } from './flow.mjs';

const QUANTITIES = ['generation', 'consumption', 'feedIn', 'purchase', 'charge', 'discharge'];

function known(value) {
    return value !== null && value !== undefined && !Number.isNaN(value);
}

/** Rounds away the noise of adding steps such as 0.1. */
function tidy(value, step) {
    const decimals = Math.max(0, Math.ceil(-Math.log(step) / Math.LN10) + 1);

    return Number(value.toFixed(decimals));
}

/**
 * A scale that holds `low`…`high` and whose marks fall on round numbers: steps of 1, 2, 2.5 or 5 times a power of ten.
 *
 * @returns `{ min, max, step, ticks }`
 */
export function niceScale(low, high, maxTicks) {
    // Without a span there is still something to draw the marks for.
    const top = high > low ? high : low + 1;
    const rough = (top - low) / maxTicks;
    const magnitude = Math.pow(10, Math.floor(Math.log(rough) / Math.LN10));
    const fraction = rough / magnitude;
    const step = (fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 2.5 ? 2.5 : fraction <= 5 ? 5 : 10) * magnitude;
    const min = tidy(Math.floor(low / step) * step, step);
    const max = tidy(Math.ceil(top / step) * step, step);
    const ticks = [];

    for (let mark = min; mark <= max + step / 2; mark += step) {
        ticks.push(tidy(mark, step));
    }

    return { min: min, max: max, step: tidy(step, step), ticks: ticks };
}

/** The sum of every quantity over the rows of parseHistory(); a quantity no row has stays null. */
export function totals(rows) {
    const sums = {};

    QUANTITIES.forEach((name) => {
        const values = rows.map((row) => row[name]).filter(known);

        sums[name] = values.length > 0 ? Number(values.reduce((sum, value) => sum + value, 0).toFixed(3)) : null;
    });

    return sums;
}

function part(value) {
    return known(value) ? Math.max(0, Number(value.toFixed(3))) : null;
}

/**
 * Where the consumption came from and where the production went, from the totals of a period.
 *
 * @returns `{ consumption: { total, solar, battery, grid }, production: { total, direct, charge, export },
 *          selfSufficiency, selfConsumption }`; the last two are shares from 0 to 1, null without a total
 */
export function balance(sums) {
    const consumed = known(sums.consumption) ? sums.consumption : null;
    const produced = known(sums.generation) ? sums.generation : null;

    return {
        consumption: {
            total: consumed,
            solar: consumed === null ? null : part(consumed - (sums.purchase || 0) - (sums.discharge || 0)),
            battery: part(sums.discharge),
            grid: part(sums.purchase),
        },
        production: {
            total: produced,
            direct: produced === null ? null : part(produced - (sums.feedIn || 0) - (sums.charge || 0)),
            charge: part(sums.charge),
            export: part(sums.feedIn),
        },
        selfSufficiency: consumed !== null && consumed > 0 ? Math.max(0, 1 - (sums.purchase || 0) / consumed) : null,
        selfConsumption: produced !== null && produced > 0 ? Math.max(0, 1 - (sums.feedIn || 0) / produced) : null,
    };
}

/**
 * The parts of a ring: every `{ key, value }` with something in it gets its `share` of the whole and
 * the stretch `from`…`to` it takes, all from 0 to 1.
 */
export function shares(parts) {
    const filled = parts.filter((item) => known(item.value) && item.value > 0);
    const whole = filled.reduce((sum, item) => sum + item.value, 0);
    let reached = 0;

    return filled.map((item) => {
        const from = reached;

        reached += item.value / whole;

        return { key: item.key, value: item.value, share: item.value / whole, from: from, to: reached };
    });
}

function stack(row, names, sign) {
    const slices = [];
    let reached = 0;

    names.forEach((name) => {
        if (known(row[name]) && row[name] > 0) {
            slices.push({ key: name, from: reached, to: reached + sign * row[name] });
            reached += sign * row[name];
        }
    });

    return slices;
}

/** A bar per row: the quantities named in `up` stacked upwards from zero, the ones in `down` downwards. */
export function stacks(rows, up, down) {
    return rows.map((row) => ({ key: row.key, up: stack(row, up, 1), down: stack(row, down, -1) }));
}

/** The lowest bottom and the highest top of the bars of stacks(). */
export function stackExtent(bars) {
    let low = 0;
    let high = 0;

    bars.forEach((bar) => {
        if (bar.up.length > 0) {
            high = Math.max(high, bar.up[bar.up.length - 1].to);
        }

        if (bar.down.length > 0) {
            low = Math.min(low, bar.down[bar.down.length - 1].to);
        }
    });

    return { low: low, high: high };
}

/**
 * The lines of the curve of a day, each a list of `[time, value]`: generation and consumption in watts,
 * the grid (positive while buying) and the battery (positive while discharging) in signed watts, and
 * the charge of the battery in percent; the signs are the ones the Deye Cloud site draws its own
 * curve with. A frame without a reading leaves a gap.
 *
 * @param frames  parseFrames() of code/deye.mjs
 * @param options `{ invertGrid, invertBattery }`
 */
export function daySeries(frames, options) {
    const settings = options || {};
    const series = { generation: [], consumption: [], grid: [], battery: [], soc: [] };
    const add = (name, time, value) => {
        if (known(value)) {
            series[name].push([time, value]);
        }
    };

    frames.forEach((frame) => {
        add('generation', frame.time, frame.generation);
        add('consumption', frame.time, frame.consumption);
        add('grid', frame.time, gridFlow(frame, settings.invertGrid === true));
        add('battery', frame.time, batteryFlow(frame, settings.invertBattery === true));
        add('soc', frame.time, frame.soc);
    });

    return series;
}

/** The index of the frame whose time is closest to `time`, -1 when there are no frames. */
export function nearestIndex(frames, time) {
    let best = -1;

    for (let index = 0; index < frames.length; index++) {
        if (best === -1 || Math.abs(frames[index].time - time) < Math.abs(frames[best].time - time)) {
            best = index;
        }
    }

    return best;
}

function amount(value) {
    return Number(value.toFixed(2));
}

/**
 * What the energy of a period was worth, from its totals and the prices of a kilowatt-hour.
 *
 * @param prices `{ buy, sell }`: what a kilowatt-hour from the grid costs, and what one sent to it brings
 * @returns `{ saved, earned, paid, benefit }`: the worth of the consumption that was not bought, what the
 *          energy sold brought, what the energy bought cost, and the first two together; null without prices
 */
export function money(sums, prices) {
    if (!(prices.buy > 0) && !(prices.sell > 0)) {
        return null;
    }

    const bought = known(sums.purchase) ? sums.purchase : 0;
    const sold = known(sums.feedIn) ? sums.feedIn : 0;
    const consumed = known(sums.consumption) ? sums.consumption : 0;
    const saved = amount(Math.max(0, consumed - bought) * prices.buy);
    const earned = amount(sold * prices.sell);

    return { saved: saved, earned: earned, paid: amount(bought * prices.buy), benefit: amount(saved + earned) };
}

/**
 * The highest production and the highest consumption of a day, each as `{ value, time }` in watts and
 * seconds since 1970; null for a quantity that was never above nothing.
 *
 * @param frames parseFrames() of code/deye.mjs
 */
export function dayPeaks(frames) {
    const peak = (name) => {
        let best = null;

        frames.forEach((frame) => {
            if (known(frame[name]) && frame[name] > 0 && (best === null || frame[name] > best.value)) {
                best = { value: frame[name], time: frame.time };
            }
        });

        return best;
    };

    return { generation: peak('generation'), consumption: peak('consumption') };
}
