import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
    authorization,
    baseUrl,
    dayRequest,
    parseDay,
    parseLatest,
    parseStations,
    parseToken,
    readHttpResponse,
    readResponse,
    retryMinutes,
    stationLatestRequest,
    stationListRequest,
    tokenNeedsRenewal,
    tokenRequest,
} from '../package/contents/code/deye.mjs';

const fixture = (name) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const data = (name) => readResponse(fixture(name)).data;

test('each data centre has its own host', () => {
    assert.equal(baseUrl('eu', ''), 'https://eu1-developer.deyecloud.com');
    assert.equal(baseUrl('us', ''), 'https://us1-developer.deyecloud.com');
    assert.equal(baseUrl('india', ''), 'https://india-developer.deyecloud.com');
});

test('a custom address is used as typed, without its trailing slash', () => {
    assert.equal(baseUrl('custom', ' http://127.0.0.1:8080/ '), 'http://127.0.0.1:8080');
});

test('an unknown data centre, or a custom one left empty, falls back to Europe', () => {
    assert.equal(baseUrl('mars', ''), 'https://eu1-developer.deyecloud.com');
    assert.equal(baseUrl('custom', '  '), 'https://eu1-developer.deyecloud.com');
});

test('the token request carries the application id in the address and the secret in the body', () => {
    const request = tokenRequest({ region: 'eu', appId: '2024 06', appSecret: 'secret', login: 'me@example.com', passwordHash: 'abc123' });

    assert.equal(request.url, 'https://eu1-developer.deyecloud.com/v1.0/account/token?appId=2024%2006');
    assert.deepEqual(request.body, { appSecret: 'secret', email: 'me@example.com', password: 'abc123' });
});

test('a login without an at sign is sent as a username', () => {
    const request = tokenRequest({ region: 'eu', appId: '1', appSecret: 's', login: ' vali ', passwordHash: 'h' });

    assert.deepEqual(request.body, { appSecret: 's', username: 'vali', password: 'h' });
});

test('a business account adds its company to the token request', () => {
    const request = tokenRequest({ region: 'eu', appId: '1', appSecret: 's', login: 'a@b.c', passwordHash: 'h', companyId: '12' });

    assert.equal(request.body.companyId, 12);
});

test('the authorization header is the scheme followed by the token', () => {
    assert.equal(authorization('eyJ'), 'bearer eyJ');
});

test('a token that already carries the scheme is not prefixed twice', () => {
    assert.equal(authorization('Bearer eyJ'), 'Bearer eyJ');
});

test('the station list is asked for in one page', () => {
    assert.deepEqual(stationListRequest('eu', ''), {
        url: 'https://eu1-developer.deyecloud.com/v1.0/station/list',
        body: { page: 1, size: 50 },
    });
});

test('the latest data is asked for by the numeric id of the station', () => {
    assert.deepEqual(stationLatestRequest('us', '', '61000001'), {
        url: 'https://us1-developer.deyecloud.com/v1.0/station/latest',
        body: { stationId: 61000001 },
    });
});

test('the totals of a day are asked for with daily granularity and the next day as the excluded end', () => {
    assert.deepEqual(dayRequest('eu', '', '61000001', '2026-10-13').body, {
        stationId: 61000001,
        granularity: 2,
        startAt: '2026-10-13',
        endAt: '2026-10-14',
    });
});

test('the day after the last of a month or of a year is the first of the next one', () => {
    assert.equal(dayRequest('eu', '', '1', '2026-10-31').body.endAt, '2026-11-01');
    assert.equal(dayRequest('eu', '', '1', '2026-12-31').body.endAt, '2027-01-01');
    assert.equal(dayRequest('eu', '', '1', '2028-02-28').body.endAt, '2028-02-29');
});

test('a successful response hands over its data', () => {
    const response = readResponse(fixture('schema-token.json'));

    assert.equal(response.ok, true);
    assert.equal(response.data.accessToken, 'token-for-tests');
});

test('a missing token is reported as a token problem', () => {
    const response = readResponse(fixture('error-token-missing.json'));

    assert.deepEqual(response, { ok: false, kind: 'token', code: '2101017', message: 'auth token not found' });
});

test('an unknown application id is reported as a credentials problem', () => {
    const response = readResponse(fixture('error-invalid-appid.json'));

    assert.deepEqual(response, { ok: false, kind: 'credentials', code: '2101021', message: 'auth invalid appId' });
});

// The wording of these two failures was not recorded from the API; the classification goes by the words alone.
test('a failure that mentions the token asks for a new one, whatever its code', () => {
    assert.equal(readResponse('{"success":false,"code":"0","msg":"access token expired"}').kind, 'token');
});

test('a failure that mentions the password or the account is a credentials problem', () => {
    assert.equal(readResponse('{"success":false,"code":"0","msg":"Wrong password"}').kind, 'credentials');
    assert.equal(readResponse('{"success":false,"code":"0","msg":"account does not exist"}').kind, 'credentials');
});

test('any other failure keeps the message of the API', () => {
    assert.deepEqual(readResponse('{"success":false,"code":"2101006","msg":"station not found"}'), {
        ok: false,
        kind: 'api',
        code: '2101006',
        message: 'station not found',
    });
});

test('a body that is not JSON is reported as malformed', () => {
    assert.equal(readResponse('<html>502 Bad Gateway</html>').kind, 'malformed');
    assert.equal(readResponse('').kind, 'malformed');
});

test('the token is kept with the moment it expires', () => {
    assert.deepEqual(parseToken(data('schema-token.json'), 1000), { accessToken: 'token-for-tests', expiresAt: 5184999 });
});

test('a token response without a lifetime is assumed to last the documented sixty days', () => {
    assert.deepEqual(parseToken({ accessToken: 'x' }, 1000), { accessToken: 'x', expiresAt: 1000 + 60 * 24 * 3600 });
});

test('a token response without a token gives nothing', () => {
    assert.equal(parseToken({ expiresIn: '10' }, 1000), null);
});

test('a token is renewed when missing, expired or within a day of expiring', () => {
    assert.equal(tokenNeedsRenewal('', 0, 1000), true);
    assert.equal(tokenNeedsRenewal('x', 900, 1000), true);
    assert.equal(tokenNeedsRenewal('x', 1000 + 3600, 1000), true);
});

test('a token with more than a day left is kept', () => {
    assert.equal(tokenNeedsRenewal('x', 1000 + 2 * 24 * 3600, 1000), false);
});

test('stations are listed with what tells them apart and with where they are', () => {
    assert.deepEqual(parseStations(data('schema-station-list.json')), [
        { id: '61000001', name: 'Acasă', capacityKw: 8.2, status: 'NORMAL', latitude: 44.18, longitude: 28.63 },
        { id: '61000002', name: 'Atelier', capacityKw: 3, status: 'ALL_OFFLINE', latitude: null, longitude: null },
    ]);
});

test('a response without stations gives an empty list', () => {
    assert.deepEqual(parseStations({}), []);
});

test('the latest data of the station is read into named powers', () => {
    assert.deepEqual(parseLatest(data('schema-station-latest.json')), {
        generation: 8,
        consumption: 900,
        feedIn: 0,
        purchase: 6,
        wire: 6,
        charge: 0,
        discharge: 908,
        battery: 908,
        soc: 51,
        updatedAt: 1791906600,
    });
});

test('a value the station does not report stays missing instead of becoming zero', () => {
    const latest = parseLatest({ generationPower: 120, batterySOC: null });

    assert.equal(latest.generation, 120);
    assert.equal(latest.soc, null);
    assert.equal(latest.consumption, null);
    assert.equal(latest.updatedAt, null);
});

test('the time of the last update is read from seconds, milliseconds or an ISO date', () => {
    assert.equal(parseLatest({ lastUpdateTime: 1791906600 }).updatedAt, 1791906600);
    assert.equal(parseLatest({ lastUpdateTime: '1791906600' }).updatedAt, 1791906600);
    assert.equal(parseLatest({ lastUpdateTime: 1791906600000 }).updatedAt, 1791906600);
    assert.equal(parseLatest({ lastUpdateTime: '2026-10-13T17:30:00Z' }).updatedAt, Date.UTC(2026, 9, 13, 17, 30) / 1000);
});

test('the totals of a day are picked by its date', () => {
    assert.deepEqual(parseDay(data('schema-station-day.json'), '2026-10-13'), {
        generation: 12.44,
        consumption: 9.8,
        feedIn: 0.356,
        purchase: 1.2,
        charge: 4,
        discharge: 3.1,
    });
});

test('a day the response does not cover has no totals', () => {
    assert.equal(parseDay(data('schema-station-day.json'), '2026-10-14'), null);
    assert.equal(parseDay({}, '2026-10-13'), null);
});

test('an answer with a body is read whatever its HTTP status', () => {
    assert.equal(readHttpResponse(200, fixture('schema-token.json')).ok, true);
    assert.equal(readHttpResponse(401, fixture('error-token-missing.json')).kind, 'token');
});

test('no HTTP status at all means the server was not reached', () => {
    assert.deepEqual(readHttpResponse(0, ''), { ok: false, kind: 'network', code: '', message: '' });
});

test('HTTP 429 is the rate limit, whatever the body says', () => {
    assert.deepEqual(readHttpResponse(429, '<html>Too Many Requests</html>'), { ok: false, kind: 'rate', code: '429', message: '' });
});

test('a gateway error page is malformed, not a crash', () => {
    assert.equal(readHttpResponse(502, '<html>Bad Gateway</html>').kind, 'malformed');
});

test('a failed refresh is retried after a minute, then twice as late every time, up to half an hour', () => {
    assert.deepEqual([1, 2, 3, 4, 5, 6, 7, 20].map(retryMinutes), [1, 2, 4, 8, 16, 30, 30, 30]);
});

// What a failure says ends up on screen, under a text in the language of the user.
test('a failure the API said nothing about brings no words of its own', () => {
    assert.equal(readResponse('<html>502 Bad Gateway</html>').message, '');
    assert.equal(readHttpResponse(0, '').message, '');
});

// A pasted AppId kept its trailing space; the first renewal of the token, weeks later, was refused.
test('an application id or secret pasted with spaces around it is sent without them', () => {
    const request = tokenRequest({ region: 'eu', appId: ' 202406 \n', appSecret: ' s3cret ', login: 'a@b.c', passwordHash: 'h' });

    assert.equal(request.url, 'https://eu1-developer.deyecloud.com/v1.0/account/token?appId=202406');
    assert.equal(request.body.appSecret, 's3cret');
});

// A station without a place set may come with 0 and 0; a forecast for the Gulf of Guinea helps nobody.
test('a station placed at exactly 0 and 0 counts as one without a place', () => {
    const [station] = parseStations({ stationList: [{ id: 1, name: 'x', locationLat: 0, locationLng: 0 }] });

    assert.equal(station.latitude, null);
    assert.equal(station.longitude, null);
});
