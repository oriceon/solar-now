// Decides what is worth a notification: a change for the worse, told once, not a state repeated with every reading.

/** A battery counts as recovered once it is this many percent above the threshold; less than that is hovering. */
const RECOVERY = 5;

/** What the widget knows before its first reading. */
export const STARTING = { batteryLow: false, silent: false, knownAlerts: null };

function known(value) {
    return value !== null && value !== undefined && !Number.isNaN(value);
}

/**
 * @param state    what the previous call returned, or STARTING
 * @param reading  `{ soc, stale, alerts }`: the charge of the battery in percent, whether the station has been
 *                 silent for long, and parseAlerts() of code/deye.mjs or null when the alerts were not asked for
 * @param settings `{ lowBattery, notifyBattery, notifySilent, notifyAlerts }`
 * @returns `{ state, events }`, where an event is `{ kind: 'battery', soc }`, `{ kind: 'silent' }`
 *          or `{ kind: 'alert', name, level }`
 */
export function watch(state, reading, settings) {
    const events = [];
    const next = { batteryLow: state.batteryLow, silent: reading.stale === true, knownAlerts: state.knownAlerts };

    if (known(reading.soc)) {
        if (reading.soc < settings.lowBattery) {
            next.batteryLow = true;
        } else if (reading.soc >= settings.lowBattery + RECOVERY) {
            next.batteryLow = false;
        }
    }

    // What is turned off is still followed, so that turning it on does not announce old news.
    if (settings.notifyBattery && next.batteryLow && !state.batteryLow) {
        events.push({ kind: 'battery', soc: reading.soc });
    }

    if (settings.notifySilent && next.silent && !state.silent) {
        events.push({ kind: 'silent' });
    }

    if (reading.alerts !== null && reading.alerts !== undefined) {
        const seen = {};

        reading.alerts.forEach((alert) => {
            seen[alert.id] = true;

            // The first list is what was already there; only what appears after it is news.
            if (settings.notifyAlerts && state.knownAlerts !== null && state.knownAlerts[alert.id] !== true && alert.open) {
                events.push({ kind: 'alert', name: alert.name, level: alert.level });
            }
        });

        next.knownAlerts = Object.assign({}, state.knownAlerts || {}, seen);
    }

    return { state: next, events: events };
}
