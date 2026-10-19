import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseMeasurePoints, readResponse } from '../package/contents/code/deye.mjs';
import { batteryCapacity, groupPoints } from '../package/contents/code/inverter.mjs';

// What a real three-phase hybrid inverter reported on 2026-10-13; the names differ from one model to another.
const devices = parseMeasurePoints(readResponse(readFileSync(new URL('./fixtures/real-device-latest.json', import.meta.url), 'utf8')).data);
const inverter = devices.filter((device) => device.type === 'INVERTER')[0];
const group = (language, id) => groupPoints(inverter.points, language).filter((found) => found.id === id)[0];
const labelOf = (language, id, key) => group(language, id).points.filter((point) => point.key === key)[0].label;

test('the capacity of the battery is its rated ampere-hours at the nominal voltage of its kind', () => {
    // 628 Ah at the 51.2 V of a 48 V lithium battery; the inverter measured 52.4 V at that moment.
    assert.equal(batteryCapacity(devices), 32.2);
});

test('the capacity does not change with how full the battery happened to be when it was asked', () => {
    const at = (volts) => [{ points: [{ key: 'BatteryRatedCapacity', value: '628', unit: 'Ah' }, { key: 'BatteryVoltage', value: String(volts), unit: 'V' }] }];

    assert.equal(batteryCapacity(at(47.9)), 32.2);
    assert.equal(batteryCapacity(at(56.1)), 32.2);
});

test('a battery of another kind keeps the voltage it reports', () => {
    assert.equal(batteryCapacity([{ points: [{ key: 'BatteryRatedCapacity', value: '50', unit: 'Ah' }, { key: 'BatteryVoltage', value: '400', unit: 'V' }] }]), 20);
});

test('no device that tells the capacity means no capacity', () => {
    assert.equal(batteryCapacity([]), null);
    assert.equal(batteryCapacity([{ points: [{ key: 'BatteryVoltage', value: '52.4', unit: 'V' }] }]), null);
    assert.equal(batteryCapacity([{ points: [{ key: 'BatteryRatedCapacity', value: '0', unit: 'Ah' }, { key: 'BatteryVoltage', value: '52.4', unit: 'V' }] }]), null);
});

test('the measure points are sorted into what they are about, in a fixed order', () => {
    assert.deepEqual(groupPoints(inverter.points, 'ro').map((found) => found.id), ['solar', 'battery', 'grid', 'load', 'inverter', 'generator']);
});

test('every point of the real inverter finds a group; none is left over', () => {
    const sizes = {};

    groupPoints(inverter.points, 'ro').forEach((found) => {
        sizes[found.id] = found.points.length;
    });

    assert.deepEqual(sizes, { solar: 16, battery: 18, grid: 23, load: 15, inverter: 20, generator: 9 });
});

test('a point about the generator is not taken for one about production', () => {
    assert.ok(group('ro', 'generator').points.some((point) => point.key === 'TotalGeneratorProduction'));
    assert.ok(group('ro', 'solar').points.every((point) => point.key.indexOf('Gen') !== 0));
});

test('the strings of panels, the phases and the totals are named in Romanian', () => {
    assert.equal(labelOf('ro', 'solar', 'DCVoltagePV2'), 'Tensiune șir 2');
    assert.equal(labelOf('ro', 'load', 'LoadPowerL3'), 'Putere consum L3');
    assert.equal(labelOf('ro', 'load', 'UPSLoadPower'), 'Putere pe ieșirea UPS');
    assert.equal(labelOf('ro', 'grid', 'TotalEnergySell'), 'Dat în rețea în total');
    assert.equal(labelOf('ro', 'battery', 'Temperature- Battery'), 'Temperatură baterie');
    assert.equal(labelOf('ro', 'inverter', 'AC Temperature'), 'Temperatură invertor');
});

test('no point of the real inverter is left with its English name in Romanian', () => {
    groupPoints(inverter.points, 'ro').forEach((found) => {
        found.points.forEach((point) => {
            const original = inverter.points.filter((given) => given.key === point.key)[0].label;

            assert.notEqual(point.label, original, point.key);
        });
    });
});

test('in English the points keep the names the API gives them', () => {
    assert.equal(labelOf('en', 'solar', 'DCVoltagePV2'), 'DC Voltage PV2');
});

test('a point no rule knows goes to a group of its own, under its own name', () => {
    const groups = groupPoints([{ key: 'SomethingNew', label: 'Something New', value: '1', unit: '' }], 'ro');

    assert.deepEqual(groups, [{ id: 'other', points: [{ key: 'SomethingNew', label: 'Something New', value: '1', unit: '' }] }]);
});

test('the value and the unit of a point pass through untouched', () => {
    assert.deepEqual(group('ro', 'load').points.filter((point) => point.key === 'UPSLoadPower')[0], { key: 'UPSLoadPower', label: 'Putere pe ieșirea UPS', value: '891', unit: 'W' });
});
