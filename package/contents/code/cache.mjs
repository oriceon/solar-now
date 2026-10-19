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
