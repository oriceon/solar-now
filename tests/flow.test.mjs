import test from 'node:test';
import assert from 'node:assert/strict';
import { batteryFlow, buildFlow, gridFlow, intensity } from '../package/contents/code/flow.mjs';

const TOWARDS_INVERTER = 1;
const AWAY_FROM_INVERTER = -1;
const IDLE = 0;

/** What the Deye Cloud app showed in the reference screenshot. */
const evening = { generation: 8, consumption: 900, feedIn: 0, purchase: 6, wire: 6, charge: 0, discharge: 908, battery: 908, soc: 51 };

const flow = (latest, options) => buildFlow(Object.assign({}, evening, latest), options);

test('panels that produce send power towards the inverter', () => {
    assert.deepEqual(flow({}).solar, { power: 8, direction: TOWARDS_INVERTER });
});

test('power bought from the grid flows towards the inverter', () => {
    assert.deepEqual(flow({}).grid, { power: 6, direction: TOWARDS_INVERTER, state: 'import' });
});

test('power sold to the grid flows away from the inverter', () => {
    assert.deepEqual(flow({ purchase: 0, feedIn: 2400, wire: -2400 }).grid, { power: 2400, direction: AWAY_FROM_INVERTER, state: 'export' });
});

test('a discharging battery sends power towards the inverter', () => {
    assert.deepEqual(flow({}).battery, { power: 908, direction: TOWARDS_INVERTER, state: 'discharge', soc: 51 });
});

test('a charging battery takes power from the inverter', () => {
    assert.deepEqual(flow({ charge: 1200, discharge: 0, battery: -1200 }).battery, { power: 1200, direction: AWAY_FROM_INVERTER, state: 'charge', soc: 51 });
});

test('consumption flows from the inverter to the house', () => {
    assert.deepEqual(flow({}).load, { power: 900, direction: AWAY_FROM_INVERTER });
});

test('the grid falls back on the signed wire power, where buying is positive', () => {
    assert.equal(flow({ purchase: null, feedIn: null, wire: 500 }).grid.state, 'import');
    assert.deepEqual(flow({ purchase: null, feedIn: null, wire: -500 }).grid, { power: 500, direction: AWAY_FROM_INVERTER, state: 'export' });
});

test('the direction of the grid can be turned around in the settings', () => {
    assert.equal(flow({ purchase: null, feedIn: null, wire: 500 }, { invertGrid: true }).grid.state, 'export');
    assert.equal(flow({}, { invertGrid: true }).grid.state, 'export');
});

test('the battery falls back on its signed power, where discharging is positive', () => {
    assert.equal(flow({ charge: null, discharge: null, battery: 300 }).battery.state, 'discharge');
    assert.deepEqual(flow({ charge: null, discharge: null, battery: -300 }).battery, { power: 300, direction: AWAY_FROM_INVERTER, state: 'charge', soc: 51 });
});

test('the direction of the battery can be turned around in the settings', () => {
    assert.equal(flow({}, { invertBattery: true }).battery.state, 'charge');
});

test('power below the idle threshold does not flow', () => {
    assert.deepEqual(flow({ generation: 0.4 }, { idleBelow: 1 }).solar, { power: 0.4, direction: IDLE });
    assert.deepEqual(flow({ consumption: 0 }).load, { power: 0, direction: IDLE });
});

test('an idle grid and an idle battery say so', () => {
    const resting = flow({ purchase: 0, feedIn: 0, wire: 0, charge: 0, discharge: 0, battery: 0 });

    assert.equal(resting.grid.state, 'idle');
    assert.equal(resting.battery.state, 'idle');
});

test('a value the station does not report stays missing and does not flow', () => {
    const blind = buildFlow({ generation: null, consumption: null, feedIn: null, purchase: null, wire: null, charge: null, discharge: null, battery: null, soc: null });

    assert.deepEqual(blind.solar, { power: null, direction: IDLE });
    assert.deepEqual(blind.grid, { power: null, direction: IDLE, state: 'idle' });
    assert.deepEqual(blind.battery, { power: null, direction: IDLE, state: 'idle', soc: null });
    assert.deepEqual(blind.load, { power: null, direction: IDLE });
});

test('the inverter is busy while anything flows', () => {
    assert.equal(flow({}).busy, true);
    assert.equal(flow({ generation: 0, consumption: 0, purchase: 0, feedIn: 0, wire: 0, charge: 0, discharge: 0, battery: 0 }).busy, false);
});

test('intensity is nothing without power and full at the reference power', () => {
    assert.equal(intensity(0, 5000), 0);
    assert.equal(intensity(null, 5000), 0);
    assert.equal(intensity(5000, 5000), 1);
    assert.equal(intensity(20000, 5000), 1);
});

test('intensity grows with power, and already shows for a few watts', () => {
    assert.ok(intensity(8, 5000) > 0.2);
    assert.ok(intensity(900, 5000) > intensity(8, 5000));
    assert.ok(intensity(900, 5000) < 1);
});

test('the grid is also available as one signed number, positive while buying', () => {
    assert.equal(gridFlow(evening, false), 6);
    assert.equal(gridFlow(Object.assign({}, evening, { purchase: 0, feedIn: 2400 }), false), -2400);
    assert.equal(gridFlow(evening, true), -6);
    assert.equal(gridFlow({ purchase: null, feedIn: null, wire: null }, false), null);
});

test('the battery is also available as one signed number, positive while discharging', () => {
    assert.equal(batteryFlow(evening, false), 908);
    assert.equal(batteryFlow(Object.assign({}, evening, { charge: 1200, discharge: 0 }), false), -1200);
    assert.equal(batteryFlow(evening, true), -908);
});

test('a one-way reading counts by its size, whatever sign the API gives it', () => {
    assert.deepEqual(flow({ charge: -1200, discharge: null, battery: -1200 }).battery, { power: 1200, direction: AWAY_FROM_INVERTER, state: 'charge', soc: 51 });
    assert.deepEqual(flow({ purchase: null, feedIn: -2400, wire: -2400 }).grid, { power: 2400, direction: AWAY_FROM_INVERTER, state: 'export' });
});

// The settings allow a threshold of 0 W; zero itself must still not flow.
test('nothing flows at zero watts, even with no idle threshold', () => {
    const resting = flow({ generation: 0, consumption: 0, purchase: 0, feedIn: null, wire: 0, charge: null, discharge: null, battery: 0 }, { idleBelow: 0 });

    assert.equal(resting.solar.direction, IDLE);
    assert.equal(resting.load.direction, IDLE);
    assert.deepEqual(resting.grid, { power: 0, direction: IDLE, state: 'idle' });
    assert.equal(resting.battery.state, 'idle');
});

test('with no idle threshold, a single watt already flows', () => {
    assert.equal(flow({ generation: 1 }, { idleBelow: 0 }).solar.direction, TOWARDS_INVERTER);
});
