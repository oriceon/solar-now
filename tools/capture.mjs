#!/usr/bin/env node
// Asks Deye Cloud what the widget asks it, with a real account, and keeps the answers as test
// fixtures with everything personal taken out. The answers show what the schema does not say:
// which values a station reports, with what sign, and how the inverter names its measure points.
//
//   node tools/capture.mjs
//
// The account is read from .credentials.json, next to the package (or from the file DEYE_CREDENTIALS names):
//   { "region": "eu", "appId": "…", "appSecret": "…", "login": "email or username", "password": "…" }
// The file is never printed, and neither is the token; .gitignore keeps it out of git.

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import {
    alertsRequest,
    authorization,
    dayRequest,
    deviceLatestRequest,
    devicesRequest,
    framesRequest,
    historyRequests,
    readHttpResponse,
    stationLatestRequest,
    stationListRequest,
    tokenRequest,
} from '../package/contents/code/deye.mjs';
import { sha256Hex } from '../package/contents/code/sha256.mjs';

const root = new URL('../', import.meta.url);
const fixtures = new URL('tests/fixtures/', root);

/** Values that name the owner or the place, replaced wherever they appear. */
const PERSONAL = {
    accessToken: 'token-removed',
    refreshToken: 'token-removed',
    uid: 0,
    name: 'Stația mea',
    locationLat: 0,
    locationLng: 0,
    locationAddress: '',
    contactPhone: '',
    ownerName: null,
};

function fail(message) {
    console.error(`capture: ${message}`);
    process.exit(1);
}

function readAccount() {
    let account = null;

    try {
        account = JSON.parse(readFileSync(process.env.DEYE_CREDENTIALS ? pathToFileURL(process.env.DEYE_CREDENTIALS) : new URL('.credentials.json', root), 'utf8'));
    } catch (error) {
        fail('.credentials.json is missing or is not JSON; see the top of this script for its shape');
    }

    ['appId', 'appSecret', 'login', 'password'].forEach((key) => {
        if (typeof account[key] !== 'string' || account[key] === '') {
            fail(`.credentials.json has no "${key}"`);
        }
    });

    return account;
}

/** Station and device ids become small made-up numbers, the same one for the same id everywhere. */
function anonymiser() {
    const stations = new Map();
    const devices = new Map();

    const station = (id) => {
        if (!stations.has(id)) {
            stations.set(id, 61000001 + stations.size);
        }

        return stations.get(id);
    };
    const device = (serial) => {
        if (!devices.has(serial)) {
            devices.set(serial, `SN${String(devices.size + 1).padStart(4, '0')}`);
        }

        return devices.get(serial);
    };

    const clean = (value, key) => {
        if (Array.isArray(value)) {
            return value.map((item) => clean(item, key));
        }

        if (value !== null && typeof value === 'object') {
            return Object.fromEntries(Object.entries(value).map(([name, inner]) => [name, clean(inner, name)]));
        }

        if (key in PERSONAL) {
            return PERSONAL[key];
        }

        if (key === 'stationId' || key === 'id') {
            return station(value);
        }

        if (key === 'deviceSn') {
            return device(value);
        }

        return key === 'deviceId' ? 0 : value;
    };

    return clean;
}

async function post(request, token) {
    const headers = { 'Content-Type': 'application/json' };

    if (token !== '') {
        headers.Authorization = authorization(token);
    }

    const answer = await fetch(request.url, { method: 'POST', headers: headers, body: JSON.stringify(request.body) });

    return { status: answer.status, limits: [...answer.headers].filter(([name]) => /limit|retry|quota/i.test(name)), response: readHttpResponse(answer.status, await answer.text()) };
}

function keep(name, data, clean) {
    writeFileSync(new URL(name, fixtures), `${JSON.stringify(clean(data, ''), null, 4)}\n`);
    console.log(`capture: kept tests/fixtures/${name}`);
}

function describe(label, data) {
    const fields = Object.keys(data).filter((key) => !['code', 'msg', 'success', 'requestId'].includes(key));

    console.log(`capture: ${label}: ${fields.map((key) => `${key}=${typeof data[key] === 'object' && data[key] !== null ? '[…]' : data[key]}`).join(', ')}`);
}

const account = readAccount();
const region = account.region || 'eu';
const customUrl = account.customUrl || '';
const passwordHash = sha256Hex(account.password);
const clean = anonymiser();

// The hash the widget computes inside Plasma has to be the one any other SHA-256 gives.
if (passwordHash !== createHash('sha256').update(account.password, 'utf8').digest('hex')) {
    fail('sha256.mjs disagrees with node:crypto on this password');
}

const issued = await post(tokenRequest({ region, customUrl, appId: account.appId, appSecret: account.appSecret, login: account.login, passwordHash, companyId: account.companyId }), '');

if (!issued.response.ok) {
    fail(`no token: ${issued.response.kind} ${issued.response.code} ${issued.response.message}`);
}

const token = issued.response.data.accessToken;

console.log(`capture: token issued, valid for ${Math.round(Number(issued.response.data.expiresIn) / 86400)} days`);
keep('real-token.json', issued.response.data, clean);

const listed = await post(stationListRequest(region, customUrl), token);

if (!listed.response.ok || (listed.response.data.stationList || []).length === 0) {
    fail(`no stations: ${listed.response.ok ? 'the account has none' : `${listed.response.code} ${listed.response.message}`}`);
}

const stations = listed.response.data.stationList;
const stationId = String(account.stationId || stations[0].id);

console.log(`capture: ${stations.length} station(s); using ${stations.findIndex((station) => String(station.id) === stationId) + 1} of ${stations.length}`);
console.log(`capture: rate-limit headers: ${listed.limits.length > 0 ? listed.limits.map(([name, value]) => `${name}=${value}`).join(', ') : 'none sent'}`);
keep('real-station-list.json', listed.response.data, clean);

const latest = await post(stationLatestRequest(region, customUrl, stationId), token);

if (!latest.response.ok) {
    fail(`no latest data: ${latest.response.code} ${latest.response.message}`);
}

describe('latest', latest.response.data);
keep('real-station-latest.json', latest.response.data, clean);

const now = new Date();
const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
const day = await post(dayRequest(region, customUrl, stationId, today), token);

if (day.response.ok) {
    describe(`totals of ${today}`, (day.response.data.stationDataItems || [{}]).slice(-1)[0] || {});
    keep('real-station-day.json', day.response.data, clean);
} else {
    console.log(`capture: no totals of the day: ${day.response.code} ${day.response.message}`);
}

// The curve of the day.
const frames = await post(framesRequest(region, customUrl, stationId, today), token);

if (frames.response.ok) {
    const items = frames.response.data.stationDataItems || [];

    console.log(`capture: curve of the day: ${items.length} points${items.length > 0 ? `, fields ${Object.keys(items[0]).filter((key) => items[0][key] !== null).join(', ')}, first timeStamp ${JSON.stringify(items[0].timeStamp)}` : ''}`);
    keep('real-station-frames.json', frames.response.data, clean);
} else {
    console.log(`capture: no curve of the day: ${frames.response.code} ${frames.response.message}`);
}

// The month by days (in two halves), the year by months and all the years.
const periods = [
    ['month', today.slice(0, 7), 'real-station-month'],
    ['year', today.slice(0, 4), 'real-station-year'],
    ['total', today.slice(0, 4), 'real-station-years'],
];

for (const [scale, anchor, name] of periods) {
    const requests = historyRequests(region, customUrl, stationId, scale, anchor);

    for (let index = 0; index < requests.length; index++) {
        const answer = await post(requests[index], token);
        const range = `${scale} ${requests[index].body.startAt}..${requests[index].body.endAt}`;

        if (answer.response.ok) {
            const items = answer.response.data.stationDataItems || [];

            console.log(`capture: ${range}: ${items.length} items, ${items.map((item) => [item.year, item.month, item.day].filter((part) => part !== null && part !== undefined).join('-')).join(' ')}`);
            keep(requests.length > 1 ? `${name}-${index + 1}.json` : `${name}.json`, answer.response.data, clean);
        } else {
            console.log(`capture: ${range}: refused, ${answer.response.code} ${answer.response.message}`);
        }
    }
}

const nowSeconds = Math.round(Date.now() / 1000);
const alerts = await post(alertsRequest(region, customUrl, stationId, nowSeconds - 30 * 86400, nowSeconds), token);

if (alerts.response.ok) {
    const items = alerts.response.data.stationAlertItems || [];

    console.log(`capture: alerts of 30 days: ${items.length}${items.length > 0 ? `, fields ${Object.keys(items[0]).join(', ')}` : ''}`);
    keep('real-station-alerts.json', alerts.response.data, clean);
} else {
    console.log(`capture: no alerts: ${alerts.response.code} ${alerts.response.message}`);
}

// The measure points of the devices; this is also where a split between the backed-up load and the
// rest of the house would come from, which the station itself does not report.
const devices = await post(devicesRequest(region, customUrl, stationId), token);

if (devices.response.ok) {
    const found = devices.response.data.deviceListItems || [];

    console.log(`capture: devices: ${found.map((device) => device.deviceType).join(', ') || 'none'}`);
    keep('real-station-devices.json', devices.response.data, clean);

    if (found.length > 0) {
        const points = await post(deviceLatestRequest(region, customUrl, found.map((device) => device.deviceSn).slice(0, 10)), token);

        if (points.response.ok) {
            (points.response.data.deviceDataList || []).forEach((device) => {
                const list = device.dataList || [];

                console.log(`capture: ${device.deviceType} measure points (${list.length}): ${list.map((point) => `${point.key}=${point.value}${point.unit || ''}`).join(', ')}`);
            });
            keep('real-device-latest.json', points.response.data, clean);
        } else {
            console.log(`capture: no device data: ${points.response.code} ${points.response.message}`);
        }
    }
} else {
    console.log(`capture: no device list: ${devices.response.code} ${devices.response.message}`);
}
