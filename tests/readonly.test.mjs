import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';

// The widget and its tools only ever read from Deye Cloud. The API can also command the inverter
// and change the station; nothing here may reach for that, not even by accident.
const READS = [
    '/v1.0/account/token',
    '/v1.0/station/list',
    '/v1.0/station/latest',
    '/v1.0/station/history',
    '/v1.0/station/alertList',
    '/v1.0/station/device',
    '/v1.0/device/latest',
];

function sources() {
    return ['../package/contents/', '../tools/'].map((folder) => {
        const base = new URL(folder, import.meta.url);

        return readdirSync(base, { recursive: true })
            .filter((name) => /\.(mjs|qml)$/.test(name))
            .map((name) => readFileSync(new URL(name, base), 'utf8'))
            .join('\n');
    }).join('\n');
}

test('every endpoint the widget and its tools name is one that only reads', () => {
    const named = new Set(sources().match(/\/v1\.0\/[A-Za-z/]+/g));

    named.forEach((endpoint) => {
        assert.ok(READS.includes(endpoint), `${endpoint} is not on the list of reads`);
    });
    assert.ok(named.size > 0);
});

test('nothing names the endpoints that command the inverter or change the station', () => {
    assert.doesNotMatch(sources(), /\/(order|strategy)\b|station\/create|device\/(register|addLogger|deleteLogger)/);
});
