// Turns the latest data of a station into what flows where around the inverter.

const TOWARDS_INVERTER = 1;
const AWAY_FROM_INVERTER = -1;
const IDLE = 0;

function known(value) {
    return value !== null && value !== undefined && !Number.isNaN(value);
}

/**
 * Power towards the inverter as a positive number, away from it as a negative one.
 * The two one-way readings are preferred; the signed one is used when neither is reported.
 * A one-way reading counts by its size: the real API sends it with the sign of the total
 * (chargePower -404, gridPower -606), which subtracted as it came turned charging into discharging.
 */
function signedPower(inward, outward, signedFallback) {
    if (known(inward) || known(outward)) {
        return (known(inward) ? Math.abs(inward) : 0) - (known(outward) ? Math.abs(outward) : 0);
    }

    return known(signedFallback) ? signedFallback : null;
}

function direction(signed, idleBelow) {
    // Zero never flows, whatever the threshold: the settings allow a threshold of 0 W.
    if (signed === null || signed === 0 || Math.abs(signed) < idleBelow) {
        return IDLE;
    }

    return signed > 0 ? TOWARDS_INVERTER : AWAY_FROM_INVERTER;
}

function oneWay(power, way, idleBelow) {
    return { power: known(power) ? power : null, direction: known(power) && power > 0 && power >= idleBelow ? way : IDLE };
}

/** Watts exchanged with the grid: positive while buying, negative while selling, null when unknown. */
export function gridFlow(reading, inverted) {
    const signed = signedPower(reading.purchase, reading.feedIn, reading.wire);

    return inverted && signed !== null ? -signed : signed;
}

/** Watts exchanged with the battery: positive while it discharges, negative while it charges, null when unknown. */
export function batteryFlow(reading, inverted) {
    const signed = signedPower(reading.discharge, reading.charge, reading.battery);

    return inverted && signed !== null ? -signed : signed;
}

function twoWay(signed, idleBelow, inwardState, outwardState) {
    const way = direction(signed, idleBelow);

    return {
        power: signed === null ? null : Math.abs(signed),
        direction: way,
        state: way === TOWARDS_INVERTER ? inwardState : way === AWAY_FROM_INVERTER ? outwardState : 'idle',
    };
}

/**
 * @param latest  parseLatest() of code/deye.mjs
 * @param options `{ idleBelow, invertGrid, invertBattery }`; power under `idleBelow` watts does not flow
 * @returns `{ solar, grid, battery, load, busy }`; every part has `power` in watts (never negative, null when
 *          unknown) and `direction`: 1 towards the inverter, -1 away from it, 0 idle
 */
export function buildFlow(latest, options) {
    const settings = options || {};
    const idleBelow = known(settings.idleBelow) ? settings.idleBelow : 1;
    const solar = oneWay(latest.generation, TOWARDS_INVERTER, idleBelow);
    const load = oneWay(latest.consumption, AWAY_FROM_INVERTER, idleBelow);
    const grid = twoWay(gridFlow(latest, settings.invertGrid === true), idleBelow, 'import', 'export');
    const battery = twoWay(batteryFlow(latest, settings.invertBattery === true), idleBelow, 'discharge', 'charge');

    battery.soc = known(latest.soc) ? latest.soc : null;

    return {
        solar: solar,
        grid: grid,
        battery: battery,
        load: load,
        busy: [solar, grid, battery, load].some((part) => part.direction !== IDLE),
    };
}

/** How lively a flow is drawn, from 0 to 1: logarithmic, so that a few watts already show. */
export function intensity(power, referencePower) {
    if (!known(power) || power <= 0) {
        return 0;
    }

    return Math.min(1, Math.log(1 + power) / Math.log(1 + referencePower));
}
