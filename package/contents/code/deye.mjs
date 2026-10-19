// Requests to the Deye Cloud OpenAPI and the reading of its answers.
// Schema: https://eu1-developer.deyecloud.com/v2/api-docs

const HOSTS = {
    eu: 'https://eu1-developer.deyecloud.com',
    us: 'https://us1-developer.deyecloud.com',
    india: 'https://india-developer.deyecloud.com',
};

/** Codes recorded from the API; anything else is classified by the words of its message. */
const TOKEN_CODES = ['2101017'];
const CREDENTIAL_CODES = ['2101021'];

const SIXTY_DAYS = 60 * 24 * 3600;
const ONE_DAY = 24 * 3600;

function numberOrNull(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }

    const number = Number(value);

    return Number.isFinite(number) ? number : null;
}

function twoDigits(value) {
    return `0${value}`.slice(-2);
}

/** `region` is eu, us, india or custom; `customUrl` is the address typed for custom. */
export function baseUrl(region, customUrl) {
    const typed = String(customUrl || '').trim().replace(/\/+$/, '');

    if (region === 'custom' && typed !== '') {
        return typed;
    }

    return HOSTS[region] || HOSTS.eu;
}

/** `account` is `{ region, customUrl, appId, appSecret, login, passwordHash, companyId }`. */
export function tokenRequest(account) {
    const login = String(account.login || '').trim();
    // A pasted id or secret may bring spaces or a line end with it.
    const body = { appSecret: String(account.appSecret || '').trim() };

    body[login.indexOf('@') === -1 ? 'username' : 'email'] = login;
    body.password = account.passwordHash;

    if (numberOrNull(account.companyId) !== null) {
        body.companyId = Number(account.companyId);
    }

    return {
        url: `${baseUrl(account.region, account.customUrl)}/v1.0/account/token?appId=${encodeURIComponent(String(account.appId || '').trim())}`,
        body: body,
    };
}

export function authorization(token) {
    return /^bearer\s/i.test(token) ? token : `bearer ${token}`;
}

export function stationListRequest(region, customUrl) {
    return { url: `${baseUrl(region, customUrl)}/v1.0/station/list`, body: { page: 1, size: 50 } };
}

export function stationLatestRequest(region, customUrl, stationId) {
    return { url: `${baseUrl(region, customUrl)}/v1.0/station/latest`, body: { stationId: Number(stationId) } };
}

/** `date` is yyyy-MM-dd, in the time of the station. */
export function dayRequest(region, customUrl, stationId, date) {
    const parts = date.split('-').map(Number);
    const next = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] + 1));

    return {
        url: `${baseUrl(region, customUrl)}/v1.0/station/history`,
        body: {
            stationId: Number(stationId),
            granularity: 2,
            startAt: date,
            endAt: `${next.getUTCFullYear()}-${twoDigits(next.getUTCMonth() + 1)}-${twoDigits(next.getUTCDate())}`,
        },
    };
}

function failureKind(code, message) {
    if (TOKEN_CODES.indexOf(code) !== -1) {
        return 'token';
    }

    if (CREDENTIAL_CODES.indexOf(code) !== -1) {
        return 'credentials';
    }

    if (/token/i.test(message)) {
        return 'token';
    }

    return /app ?id|secret|password|account|user/i.test(message) ? 'credentials' : 'api';
}

/**
 * The API answers failures with HTTP 200 too, and tells them apart in the body.
 *
 * @returns `{ ok: true, data }`, or `{ ok: false, kind, code, message }` where kind is token (ask for a
 *          new one), credentials, api or malformed, and message holds the words of the API, if it had any.
 */
export function readResponse(text) {
    let body = null;

    try {
        body = JSON.parse(text);
    } catch (error) {
        body = null;
    }

    if (body === null || typeof body !== 'object') {
        return { ok: false, kind: 'malformed', code: '', message: '' };
    }

    if (body.success === true) {
        return { ok: true, data: body };
    }

    const code = String(body.code === undefined || body.code === null ? '' : body.code);
    const message = String(body.msg || '');

    return { ok: false, kind: failureKind(code, message), code: code, message: message };
}

/** readResponse(), with the two failures only the HTTP status tells: no connection (status 0) and the rate limit. */
export function readHttpResponse(status, text) {
    if (status === 0) {
        return { ok: false, kind: 'network', code: '', message: '' };
    }

    if (status === 429) {
        return { ok: false, kind: 'rate', code: '429', message: '' };
    }

    return readResponse(text);
}

/** Minutes to wait before trying again after `failures` failed refreshes in a row. */
export function retryMinutes(failures) {
    return Math.min(30, Math.pow(2, Math.max(1, failures) - 1));
}

/** @returns `{ accessToken, expiresAt }` with the expiry in seconds since 1970, or null. */
export function parseToken(data, nowSeconds) {
    if (typeof data.accessToken !== 'string' || data.accessToken === '') {
        return null;
    }

    const lifetime = numberOrNull(data.expiresIn);

    return { accessToken: data.accessToken, expiresAt: nowSeconds + (lifetime !== null && lifetime > 0 ? lifetime : SIXTY_DAYS) };
}

export function tokenNeedsRenewal(accessToken, expiresAt, nowSeconds) {
    return accessToken === '' || !(expiresAt - nowSeconds > ONE_DAY);
}

export function parseStations(data) {
    return (data.stationList || []).map((station) => ({
        id: String(station.id),
        name: String(station.name || station.id),
        capacityKw: numberOrNull(station.installedCapacity),
        status: String(station.connectionStatus || ''),
        // A station without a place set may come with 0 and 0, which is in the sea off Africa.
        latitude: station.locationLat === 0 && station.locationLng === 0 ? null : numberOrNull(station.locationLat),
        longitude: station.locationLat === 0 && station.locationLng === 0 ? null : numberOrNull(station.locationLng),
    }));
}

/** Seconds since 1970 from seconds, milliseconds or an ISO date. */
function seconds(value) {
    const number = numberOrNull(value);

    if (number !== null) {
        return number > 100000000000 ? Math.round(number / 1000) : number;
    }

    const parsed = typeof value === 'string' ? Date.parse(value) : NaN;

    return Number.isNaN(parsed) ? null : Math.round(parsed / 1000);
}

/** Powers in watts, the charge of the battery in percent; a value the station does not report is null. */
export function parseLatest(data) {
    return {
        generation: numberOrNull(data.generationPower),
        consumption: numberOrNull(data.consumptionPower),
        feedIn: numberOrNull(data.gridPower),
        purchase: numberOrNull(data.purchasePower),
        wire: numberOrNull(data.wirePower),
        charge: numberOrNull(data.chargePower),
        discharge: numberOrNull(data.dischargePower),
        battery: numberOrNull(data.batteryPower),
        soc: numberOrNull(data.batterySOC),
        updatedAt: seconds(data.lastUpdateTime),
    };
}

/** The energy of an item of the history, in kWh. */
function energyOf(item) {
    return {
        generation: numberOrNull(item.generationValue),
        consumption: numberOrNull(item.consumptionValue),
        feedIn: numberOrNull(item.gridValue),
        purchase: numberOrNull(item.purchaseValue),
        charge: numberOrNull(item.chargeValue),
        discharge: numberOrNull(item.dischargeValue),
    };
}

/** Energy of the day `date` (yyyy-MM-dd) in kWh, or null when the answer does not cover it. */
export function parseDay(data, date) {
    const parts = date.split('-').map(Number);
    const items = data.stationDataItems || [];

    for (let index = 0; index < items.length; index++) {
        const item = items[index];

        if (item.year === parts[0] && item.month === parts[1] && item.day === parts[2]) {
            return energyOf(item);
        }
    }

    return null;
}

/**
 * The powers of the station through the day `date` (yyyy-MM-dd), a frame every five minutes.
 * The API refuses the request without an end, whatever the schema says.
 */
export function framesRequest(region, customUrl, stationId, date) {
    return { url: `${baseUrl(region, customUrl)}/v1.0/station/history`, body: { stationId: Number(stationId), granularity: 1, startAt: date, endAt: date } };
}

/**
 * The requests for the energy of a period, one item per part of it. How the API counts the end of
 * a range was recorded from it: not counted for days, counted for months and for years.
 *
 * @param scale  month (its days), year (its months) or total (the ten years up to `anchor`)
 * @param anchor yyyy-MM for a month, yyyy otherwise
 * @returns one request, or two for a month: the API takes at most 30 days at once
 */
export function historyRequests(region, customUrl, stationId, scale, anchor) {
    const url = `${baseUrl(region, customUrl)}/v1.0/station/history`;
    const id = Number(stationId);
    const year = Number(anchor.slice(0, 4));

    if (scale === 'month') {
        const next = new Date(Date.UTC(year, Number(anchor.slice(5, 7)), 1));
        const afterMonth = `${next.getUTCFullYear()}-${twoDigits(next.getUTCMonth() + 1)}-01`;

        return [
            { url: url, body: { stationId: id, granularity: 2, startAt: `${anchor}-01`, endAt: `${anchor}-16` } },
            { url: url, body: { stationId: id, granularity: 2, startAt: `${anchor}-16`, endAt: afterMonth } },
        ];
    }

    if (scale === 'year') {
        return [{ url: url, body: { stationId: id, granularity: 3, startAt: `${year}-01`, endAt: `${year}-12` } }];
    }

    return [{ url: url, body: { stationId: id, granularity: 4, startAt: String(year - 9), endAt: String(year) } }];
}

/** The days before `today` (yyyy-MM-dd), two weeks of them, one item each; the end of a range of days is not counted. */
export function recentDaysRequest(region, customUrl, stationId, today) {
    const parts = today.split('-').map(Number);
    const start = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] - 14));

    return {
        url: `${baseUrl(region, customUrl)}/v1.0/station/history`,
        body: {
            stationId: Number(stationId),
            granularity: 2,
            startAt: `${start.getUTCFullYear()}-${twoDigits(start.getUTCMonth() + 1)}-${twoDigits(start.getUTCDate())}`,
            endAt: today,
        },
    };
}

/** `{ date, generation }` of every day of an answer by days: its date as yyyy-MM-dd and what it produced, in kWh. */
export function parseDailyGeneration(data) {
    return (data.stationDataItems || [])
        .map((item) => ({ date: `${item.year}-${twoDigits(item.month)}-${twoDigits(item.day)}`, generation: numberOrNull(item.generationValue) }))
        .sort((early, late) => (early.date < late.date ? -1 : 1));
}

/** parseLatest() of every frame, with its `time` in seconds since 1970, in the order of time. */
export function parseFrames(data) {
    return (data.stationDataItems || [])
        .map((item) => Object.assign(parseLatest(item), { time: seconds(item.timeStamp) }))
        .filter((frame) => frame.time !== null)
        .sort((early, late) => early.time - late.time);
}

/**
 * Rows of energy in kWh, `{ key, generation, consumption, feedIn, purchase, charge, discharge }`, where
 * key is the day of the month, the month of the year or the year, by `scale`. Of all the years, only
 * those with any energy are kept: the station did not exist in the others.
 */
export function parseHistory(data, scale, anchor) {
    const year = Number(anchor.slice(0, 4));
    const month = Number(anchor.slice(5, 7));
    const rows = [];

    (data.stationDataItems || []).forEach((item) => {
        const row = energyOf(item);

        if (scale === 'month' && item.year === year && item.month === month) {
            row.key = item.day;
        } else if (scale === 'year' && item.year === year) {
            row.key = item.month;
        } else if (scale === 'total' && item.year <= year && ['generation', 'consumption', 'feedIn', 'purchase', 'charge', 'discharge'].some((name) => row[name] !== null && row[name] > 0)) {
            row.key = item.year;
        }

        if (typeof row.key === 'number') {
            rows.push(row);
        }
    });

    return rows.sort((early, late) => early.key - late.key);
}

/**
 * The alerts of the station between two moments, in seconds since 1970; the API allows 180 days at most,
 * and 200 alerts in one answer, the most it gives at once.
 */
export function alertsRequest(region, customUrl, stationId, fromSeconds, toSeconds) {
    return {
        url: `${baseUrl(region, customUrl)}/v1.0/station/alertList`,
        body: { stationId: Number(stationId), startTimestamp: fromSeconds, endTimestamp: toSeconds, page: 1, size: 200 },
    };
}

const ALERT_LEVELS = ['notice', 'warning', 'failure'];

/** `{ id, name, level, open, startedAt, endedAt, device }`, newest first; level is notice, warning or failure. */
export function parseAlerts(data) {
    return (data.stationAlertItems || [])
        .map((item) => ({
            id: String(item.alertId),
            name: String(item.alertName || item.alertCode || ''),
            level: ALERT_LEVELS[item.level] || 'notice',
            open: item.status === 1,
            startedAt: seconds(item.alertStartTime),
            endedAt: item.status === 1 ? null : seconds(item.alertEndTime),
            device: String(item.deviceSn || ''),
        }))
        .sort((early, late) => (late.startedAt || 0) - (early.startedAt || 0));
}

export function devicesRequest(region, customUrl, stationId) {
    return { url: `${baseUrl(region, customUrl)}/v1.0/station/device`, body: { page: 1, size: 20, stationIds: [Number(stationId)] } };
}

export function parseDevices(data) {
    return (data.deviceListItems || []).map((item) => ({ serial: String(item.deviceSn), type: String(item.deviceType || '') }));
}

/** The latest measure points of up to ten devices, by serial number. */
export function deviceLatestRequest(region, customUrl, serials) {
    return { url: `${baseUrl(region, customUrl)}/v1.0/device/latest`, body: { deviceList: serials } };
}

/** "DCVoltagePV1" as "DC Voltage PV1": a space before every word and before a trailing group of capitals and digits. */
function readable(key) {
    return String(key)
        .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
        .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
        .trim();
}

/**
 * What every device reports, as the API names it: `{ serial, type, collectedAt, points }`, where a point
 * is `{ key, label, value, unit }`. The names differ from one inverter model to another.
 */
export function parseMeasurePoints(data) {
    return (data.deviceDataList || []).map((device) => ({
        serial: String(device.deviceSn),
        type: String(device.deviceType || ''),
        collectedAt: seconds(device.collectionTime),
        points: (device.dataList || []).map((point) => ({
            key: String(point.key),
            label: readable(point.key),
            value: point.value === null || point.value === undefined ? '' : String(point.value),
            unit: point.unit ? String(point.unit) : '',
        })),
    }));
}
