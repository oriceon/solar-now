import test from 'node:test';
import assert from 'node:assert/strict';
import { STARTING, watch } from '../package/contents/code/watch.mjs';

const all = { lowBattery: 20, notifyBattery: true, notifySilent: true, notifyAlerts: true };
const calm = { soc: 60, stale: false, alerts: null };
const alert = (id, open) => ({ id: id, name: `Alert ${id}`, level: 'warning', open: open });

/** Feeds the readings one after the other and returns the events each of them raised. */
function run(readings, settings) {
    let state = STARTING;

    return readings.map((reading) => {
        const result = watch(state, Object.assign({}, calm, reading), settings || all);

        state = result.state;

        return result.events;
    });
}

test('nothing is raised while all is well', () => {
    assert.deepEqual(run([{}, {}, {}]), [[], [], []]);
});

test('a battery that falls under the threshold is announced once, not with every reading', () => {
    assert.deepEqual(run([{ soc: 25 }, { soc: 19 }, { soc: 18 }, { soc: 15 }]), [[], [{ kind: 'battery', soc: 19 }], [], []]);
});

test('a battery that is already low when the widget starts is announced', () => {
    assert.deepEqual(run([{ soc: 12 }])[0], [{ kind: 'battery', soc: 12 }]);
});

test('a battery hovering around the threshold is not announced again until it has clearly recovered', () => {
    const events = run([{ soc: 19 }, { soc: 21 }, { soc: 19 }, { soc: 26 }, { soc: 19 }]);

    assert.deepEqual(events.map((raised) => raised.length), [1, 0, 0, 0, 1]);
});

test('an unknown charge neither announces nor forgets', () => {
    assert.deepEqual(run([{ soc: 19 }, { soc: null }, { soc: 18 }]).map((raised) => raised.length), [1, 0, 0]);
});

test('a station that falls silent is announced once, and again only after it has spoken in between', () => {
    const events = run([{ stale: true }, { stale: true }, { stale: false }, { stale: true }]);

    assert.deepEqual(events, [[{ kind: 'silent' }], [], [], [{ kind: 'silent' }]]);
});

test('the alerts found at the start are taken as known, not announced', () => {
    assert.deepEqual(run([{ alerts: [alert('a', true), alert('b', false)] }])[0], []);
});

test('an alert that appears later is announced once', () => {
    const events = run([{ alerts: [alert('a', true)] }, { alerts: [alert('b', true), alert('a', true)] }, { alerts: [alert('b', true), alert('a', true)] }]);

    assert.deepEqual(events, [[], [{ kind: 'alert', name: 'Alert b', level: 'warning' }], []]);
});

test('an alert that is already over when it is first seen is not announced', () => {
    assert.deepEqual(run([{ alerts: [] }, { alerts: [alert('c', false)] }])[1], []);
});

test('readings without the list of alerts leave what is known alone', () => {
    const events = run([{ alerts: [alert('a', true)] }, { alerts: null }, { alerts: [alert('a', true)] }]);

    assert.deepEqual(events, [[], [], []]);
});

test('what is turned off in the settings is not announced', () => {
    const quiet = { lowBattery: 20, notifyBattery: false, notifySilent: false, notifyAlerts: false };

    assert.deepEqual(run([{ alerts: [] }, { soc: 5, stale: true, alerts: [alert('z', true)] }], quiet), [[], []]);
});

test('turning a notification on later does not announce what has been going on all along', () => {
    let state = STARTING;
    const off = Object.assign({}, all, { notifyBattery: false });

    state = watch(state, Object.assign({}, calm, { soc: 10 }), off).state;

    assert.deepEqual(watch(state, Object.assign({}, calm, { soc: 9 }), all).events, []);
});
