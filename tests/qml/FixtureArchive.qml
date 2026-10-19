import QtQuick

import "../../package/contents/code/deye.mjs" as Deye
import "../../package/contents/code/forecast.mjs" as Forecast

// Stands in for ArchiveStore on the stage: answers at once, from the fixtures, without the network.
QtObject {
    id: archive

    property string framesJson
    property string monthJson
    property string yearJson
    property string yearsJson
    property string alertsJson
    property string deviceJson
    property string stationsJson
    /** An answer of Open-Meteo with the radiation of the days around the one the stage pretends it is. */
    property string radiationJson
    /** The day the frames of the fixture belong to; any other day has none. */
    property string framesDay: "2026-10-13"
    /** How every answer is staged: ready, empty, loading or failed. */
    property string outcome: "ready"

    readonly property int alertDays: 30
    property var entries: ({})

    signal stale()

    function framesKey(date: string): string {
        return `frames|${date}`;
    }

    function historyKey(scale: string, anchor: string): string {
        return `history|${scale}|${anchor}`;
    }

    function alertsKey(): string {
        return "alerts";
    }

    function devicesKey(): string {
        return "devices";
    }

    function stationsKey(): string {
        return "stations";
    }

    function forecastKey(today: string): string {
        return `forecast|${today}`;
    }

    function loadForecast(today: string, latitude: real, longitude: real): void {
        put(forecastKey(today), { days: Deye.parseDailyGeneration(data(monthJson)), radiation: Forecast.parseRadiation(JSON.parse(radiationJson)) });
    }

    function loadStations(): void {
        put(stationsKey(), Deye.parseStations(data(stationsJson)));
    }

    function data(json: string): var {
        return Deye.readResponse(json).data;
    }

    function put(key: string, answer: var): void {
        const next = Object.assign({}, entries);

        next[key] = {
            status: outcome === "ready" || outcome === "empty" ? "ready" : outcome,
            data: outcome === "ready" ? answer : outcome === "empty" ? [] : null,
            at: Date.now(),
        };
        entries = next;
    }

    function loadFrames(date: string, today: string): void {
        put(framesKey(date), date === framesDay ? Deye.parseFrames(data(framesJson)) : []);
    }

    function loadHistory(scale: string, anchor: string, currentAnchor: string): void {
        put(historyKey(scale, anchor), Deye.parseHistory(data(scale === "month" ? monthJson : scale === "year" ? yearJson : yearsJson), scale, anchor));
    }

    function loadAlerts(): void {
        put(alertsKey(), Deye.parseAlerts(data(alertsJson)));
    }

    function loadDevices(): void {
        put(devicesKey(), Deye.parseMeasurePoints(data(deviceJson)));
    }
}
