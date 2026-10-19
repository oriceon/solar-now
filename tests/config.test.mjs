import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const schema = readFileSync(new URL('../package/contents/config/main.xml', import.meta.url), 'utf8');

/** The default of a setting, as main.xml gives it. */
function defaultOf(name) {
    const entry = new RegExp(`<entry name="${name}"[^>]*>[\\s\\S]*?<default>([^<]*)</default>`).exec(schema);

    return entry ? entry[1] : undefined;
}

test('a new widget takes the background of the Plasma theme', () => {
    assert.equal(defaultOf('background'), 'theme');
});
