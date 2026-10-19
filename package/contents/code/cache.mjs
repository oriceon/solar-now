// When an answer the widget keeps has to be asked for again.

/** A request that has not answered by then is taken as lost: after a suspend, one may never answer. */
export const PATIENCE_SECONDS = 60;

/**
 * @param entry       what is on hand: `{ status, at, current }`, where status is loading, ready or failed, `at` is
 *                    when it was asked for or came, in milliseconds, and `current` tells whether its period was
 *                    still going on then; undefined when nothing is on hand
 * @param current     whether the period is going on now
 * @param keepMinutes how long an answer about a period that is going on stays good
 */
export function needsLoading(entry, current, keepMinutes, nowMs) {
    if (entry === undefined || entry === null || entry.status === 'failed') {
        return true;
    }

    const age = nowMs - entry.at;

    if (entry.status === 'loading') {
        return age >= PATIENCE_SECONDS * 1000;
    }

    // An answer that came while its period was going on is incomplete once the period is over.
    return current || entry.current ? age >= keepMinutes * 60 * 1000 : false;
}

/**
 * The refresh intervals offered, in minutes. Deye refreshes the data of a station at most every
 * 5 minutes, so asking more often only brings the same data again (its API usage best practices).
 */
export const REFRESH_CHOICES = [5, 10, 15, 30];

/** The refresh interval of the settings, raised to the least one: versions before 1.0.2 also offered 1 and 2 minutes. */
export function refreshMinutes(setting) {
    return Math.max(REFRESH_CHOICES[0], Number(setting) || REFRESH_CHOICES[0]);
}

/** A refresh asked for by hand repeats nothing that came in the last minute: what is on screen is as new as it gets. */
export const HAND_REFRESH_SECONDS = 60;

/** @param fetchedAtMs when the answer on hand came, in milliseconds; NaN or 0 while none has */
export function worthRefreshing(fetchedAtMs, nowMs) {
    return !(fetchedAtMs > 0) || nowMs - fetchedAtMs >= HAND_REFRESH_SECONDS * 1000;
}
