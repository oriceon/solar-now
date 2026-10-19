import QtQuick

import "../code/cache.mjs" as Cache
import "../code/deye.mjs" as Deye
import "../code/forecast.mjs" as Forecast

/**
 * Loads what the tabs beside the live flow show: the curve of a day, the energy of a period, the
 * alerts and the measure points of the devices. Nothing is asked for until a tab wants it, and an
 * answer is kept: for good when it is about a past period, for a few minutes when about the present.
 */
QtObject {
    id: archive

    /** The store of the live data: it knows the account and the station, and hands out the token. */
    required property SolarStore source
    /** Minutes an answer about the present is kept before it is asked for again. */
    property int freshMinutes: 10
    /** How far back the alerts go. */
    readonly property int alertDays: 30
    /** Where the forecast of solar radiation is asked for. */
    property string forecastHost: "https://api.open-meteo.com"
    /** A forecast of the weather does not change by the minute. */
    readonly property int forecastMinutes: 180
    /** Neither does the list of stations of an account; a refresh asked for by hand still fetches it anew. */
    readonly property int stationsMinutes: 720

    /**
     * Answers by key: `{ status, data, at }` with status loading, ready or failed. The whole object is
     * replaced on every change, so that whatever is bound to it notices.
     */
    property var entries: ({})

    readonly property ApiClient client: ApiClient {}

    /** The answers on hand may be out of date: whoever shows one should ask for it again. */
    signal stale()

    function framesKey(date: string): string {
        return `${source.requestKey}|frames|${date}`;
    }

    function historyKey(scale: string, anchor: string): string {
        return `${source.requestKey}|history|${scale}|${anchor}`;
    }

    function alertsKey(): string {
        return `${source.requestKey}|alerts`;
    }

    function devicesKey(): string {
        return `${source.requestKey}|devices`;
    }

    /** The stations belong to the account, not to the station on show. */
    function stationsKey(): string {
        return `${source.region}|${source.customUrl}|${source.appId}|stations`;
    }

    /** By day: after midnight, yesterday's tomorrow has become today and a new tomorrow is needed. */
    function forecastKey(today: string): string {
        return `${source.requestKey}|forecast|${today}`;
    }

    /** `current` tells whether the period of the answer was still going on; see needsLoading() in code/cache.mjs. */
    function put(key: string, status: string, data: var, current: bool): void {
        const next = Object.assign({}, entries);

        next[key] = { status: status, data: data, at: Date.now(), current: current };
        entries = next;
    }

    /**
     * Runs `fetch(token, done)` unless the answer on hand will do; `done(data)` keeps the answer,
     * `done(null)` marks it failed. `current` tells an answer about the present, which goes stale
     * after `keepMinutes`, or after the usual few when that is left out.
     */
    function load(key: string, current: bool, fetch: var, keepMinutes = freshMinutes): void {
        const have = entries[key];

        if (!source.configured || !Cache.needsLoading(have, current, keepMinutes, Date.now())) {
            return;
        }

        // What was shown before stays on screen while the new answer is on its way, and if it does not come.
        const previous = have !== undefined ? have.data : null;

        put(key, "loading", previous, current);
        source.withToken(token => fetch(token, data => archive.put(key, data !== null ? "ready" : "failed", data !== null ? data : previous, current)), () => archive.put(key, "failed", previous, current));
    }

    /** The curve of the day `date`; `today` tells whether that day is still going on. */
    function loadFrames(date: string, today: string): void {
        load(framesKey(date), date === today, (token, done) => {
            archive.client.post(Deye.framesRequest(source.region, source.customUrl, source.stationId, date), token, response => {
                done(response.ok ? Deye.parseFrames(response.data) : null);
            });
        });
    }

    /** The energy of the period `anchor` of `scale`; `currentAnchor` is the period today is in. */
    function loadHistory(scale: string, anchor: string, currentAnchor: string): void {
        const requests = Deye.historyRequests(source.region, source.customUrl, source.stationId, scale, anchor);

        load(historyKey(scale, anchor), anchor === currentAnchor, (token, done) => {
            let rows = [];
            let awaited = requests.length;
            let failed = false;

            // A month comes in two answers; the period is on hand when both are.
            requests.forEach(request => {
                archive.client.post(request, token, response => {
                    failed = failed || !response.ok;
                    rows = response.ok ? rows.concat(Deye.parseHistory(response.data, scale, anchor)) : rows;
                    awaited--;

                    if (awaited === 0) {
                        done(failed ? null : rows.sort((early, late) => early.key - late.key));
                    }
                });
            });
        });
    }

    /** The stations of the account, to switch between them from the widget itself. */
    function loadStations(): void {
        load(stationsKey(), true, (token, done) => {
            archive.client.post(Deye.stationListRequest(source.region, source.customUrl), token, response => {
                done(response.ok ? Deye.parseStations(response.data) : null);
            });
        }, stationsMinutes);
    }

    /**
     * What an estimate of the production needs: what the last two weeks produced, day by day, and the
     * solar radiation of those days, of today and of tomorrow at the place of the station.
     */
    function loadForecast(today: string, latitude: real, longitude: real): void {
        load(forecastKey(today), true, (token, done) => {
            archive.client.post(Deye.recentDaysRequest(source.region, source.customUrl, source.stationId, today), token, response => {
                if (!response.ok) {
                    done(null);

                    return;
                }

                const days = Deye.parseDailyGeneration(response.data);
                const call = new XMLHttpRequest();

                call.onreadystatechange = () => {
                    if (call.readyState !== XMLHttpRequest.DONE) {
                        return;
                    }

                    let radiation = null;

                    try {
                        radiation = call.status === 200 ? Forecast.parseRadiation(JSON.parse(call.responseText)) : null;
                    } catch (error) {
                        radiation = null;
                    }

                    done(radiation !== null ? { days: days, radiation: radiation } : null);
                };

                call.open("GET", Forecast.radiationUrl(archive.forecastHost, latitude, longitude));
                call.send();
            });
        }, forecastMinutes);
    }

    function loadAlerts(): void {
        const now = Math.round(Date.now() / 1000);

        load(alertsKey(), true, (token, done) => {
            archive.client.post(Deye.alertsRequest(source.region, source.customUrl, source.stationId, now - alertDays * 86400, now), token, response => {
                done(response.ok ? Deye.parseAlerts(response.data) : null);
            });
        });
    }

    /** The devices of the station first, then what each of them measures. */
    function loadDevices(): void {
        load(devicesKey(), true, (token, done) => {
            archive.client.post(Deye.devicesRequest(source.region, source.customUrl, source.stationId), token, listed => {
                const serials = listed.ok ? Deye.parseDevices(listed.data).map(device => device.serial).slice(0, 10) : [];

                if (serials.length === 0) {
                    done(listed.ok ? [] : null);

                    return;
                }

                archive.client.post(Deye.deviceLatestRequest(source.region, source.customUrl, serials), token, response => {
                    done(response.ok ? Deye.parseMeasurePoints(response.data).filter(device => device.points.length > 0) : null);
                });
            });
        });
    }

    /** After a refresh asked for by hand, nothing about the present is trusted any more. */
    function refresh(): void {
        const next = {};

        // A request still on its way is left to answer: asking again would only send it twice.
        Object.keys(entries).forEach(key => {
            next[key] = entries[key].status === "loading" ? entries[key] : Object.assign({}, entries[key], { at: 0 });
        });

        entries = next;
        stale();
    }

    readonly property Connections sourceWatch: Connections {
        target: archive.source

        // Every refresh of the live data is a chance to bring what is on screen up to date.
        function onFetchedAtChanged(): void {
            archive.stale();
        }
    }
}
