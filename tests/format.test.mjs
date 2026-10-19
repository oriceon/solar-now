import test from 'node:test';
import assert from 'node:assert/strict';
import { duration, energy, money, percent, power, price } from '../package/contents/code/format.mjs';

test('power below a kilowatt is shown in whole watts', () => {
    assert.equal(power(8, 'auto', 'ro'), '8 W');
    assert.equal(power(907.6, 'auto', 'ro'), '908 W');
});

test('power from a kilowatt up is shown in kilowatts, with the decimal mark of the language', () => {
    assert.equal(power(1250, 'auto', 'ro'), '1,25 kW');
    assert.equal(power(1250, 'auto', 'en'), '1.25 kW');
});

test('power from ten kilowatts up keeps one decimal', () => {
    assert.equal(power(12540, 'auto', 'ro'), '12,5 kW');
});

test('power that rounds up to a kilowatt is not shown as 1000 W', () => {
    assert.equal(power(999.6, 'auto', 'ro'), '1,00 kW');
});

test('power can be forced to watts or to kilowatts', () => {
    assert.equal(power(1250, 'w', 'ro'), '1250 W');
    assert.equal(power(908, 'kw', 'ro'), '0,91 kW');
});

test('power never shows a negative zero', () => {
    assert.equal(power(-0.2, 'auto', 'ro'), '0 W');
});

test('power shows a dash while there is no value', () => {
    assert.equal(power(null, 'auto', 'ro'), '–');
    assert.equal(power(undefined, 'auto', 'ro'), '–');
    assert.equal(power(NaN, 'auto', 'ro'), '–');
});

test('energy keeps fewer decimals as it grows', () => {
    assert.equal(energy(0.356, 'ro'), '0,36 kWh');
    assert.equal(energy(12.44, 'ro'), '12,4 kWh');
    assert.equal(energy(123.4, 'ro'), '123 kWh');
});

test('energy from a thousand kilowatt-hours up is shown in megawatt-hours', () => {
    assert.equal(energy(1250, 'en'), '1.25 MWh');
});

test('energy shows a dash while there is no value', () => {
    assert.equal(energy(null, 'ro'), '–');
});

test('percent rounds to a whole number', () => {
    assert.equal(percent(51.4), '51%');
    assert.equal(percent(99.5), '100%');
});

test('percent shows a dash while there is no value', () => {
    assert.equal(percent(null), '–');
});

test('money is shown with two decimals and its currency', () => {
    assert.equal(money(12.4, 'lei', 'ro'), '12,40 lei');
    assert.equal(money(0.306, 'EUR', 'en'), '0.31 EUR');
});

test('money from a thousand up drops the decimals', () => {
    assert.equal(money(1250.6, 'lei', 'ro'), '1251 lei');
});

test('money shows a dash while there is no value', () => {
    assert.equal(money(null, 'lei', 'ro'), '–');
});

test('a price typed with a comma or a point is read the same', () => {
    assert.equal(price('1,30'), 1.3);
    assert.equal(price(' 0.45 '), 0.45);
});

test('a price that is not a number, or is below zero, is no price', () => {
    assert.equal(price('abc'), 0);
    assert.equal(price(''), 0);
    assert.equal(price('-2'), 0);
});
