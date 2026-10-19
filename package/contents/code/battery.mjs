// How long the battery lasts, or takes to fill, if things stay as they are now.

function known(value) {
    return value !== null && value !== undefined && !Number.isNaN(value);
}

/**
 * @param battery `{ soc, power, direction, capacity, reserve }`: its charge in percent, the watts it
 *                exchanges and which way (1 discharging, -1 charging, 0 resting; see code/flow.mjs),
 *                its capacity in kWh, and the percent under which the inverter no longer draws from it
 * @returns `{ state, hours }` with state discharge (hours until the reserve is reached) or charge
 *          (hours until it is full); null while it rests or something is not known
 */
export function batteryTime(battery) {
    if (!known(battery.soc) || !known(battery.power) || !known(battery.capacity) || battery.direction === 0 || !(battery.power > 0) || !(battery.capacity > 0)) {
        return null;
    }

    const state = battery.direction > 0 ? 'discharge' : 'charge';
    const percent = state === 'discharge' ? battery.soc - battery.reserve : 100 - battery.soc;

    return { state: state, hours: Math.max(0, percent) / 100 * battery.capacity / (battery.power / 1000) };
}
