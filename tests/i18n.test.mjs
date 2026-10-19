import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { STRINGS, resolveLanguage, t } from '../package/contents/code/i18n.mjs';

test('an explicit language setting wins over the language of the system', () => {
    assert.equal(resolveLanguage('ro', ['en-US', 'en']), 'ro');
    assert.equal(resolveLanguage('en', ['ro-RO', 'ro']), 'en');
});

test('auto follows the language of the interface, not the regional formats', () => {
    // The setup of the user: Plasma in American English, dates and numbers in Romanian.
    assert.equal(resolveLanguage('auto', ['en-US', 'en']), 'en');
    assert.equal(resolveLanguage('auto', ['ro-RO', 'ro']), 'ro');
    assert.equal(resolveLanguage('auto', ['ro_RO']), 'ro');
});

test('auto takes the first language of the interface the widget speaks', () => {
    assert.equal(resolveLanguage('auto', ['de-DE', 'de', 'ro-RO']), 'ro');
});

test('auto falls back to English when the interface speaks nothing the widget does', () => {
    assert.equal(resolveLanguage('auto', ['de-DE', 'fr']), 'en');
    assert.equal(resolveLanguage('auto', []), 'en');
    assert.equal(resolveLanguage('auto', undefined), 'en');
});

test('an unsupported setting behaves like auto', () => {
    assert.equal(resolveLanguage('', ['ro-RO']), 'ro');
    assert.equal(resolveLanguage('de', ['en-US']), 'en');
});

test('t returns the text in the requested language', () => {
    assert.equal(t('ro', 'node.solar'), 'Panouri');
    assert.equal(t('en', 'node.solar'), 'Solar');
});

test('t substitutes named parameters', () => {
    assert.equal(t('ro', 'header.updated', { time: '17:30' }), 'Actualizat la 17:30');
});

test('t returns the key for a text that does not exist', () => {
    assert.equal(t('ro', 'no.such.key'), 'no.such.key');
});

test('both languages have exactly the same texts', () => {
    assert.deepEqual(Object.keys(STRINGS.ro).sort(), Object.keys(STRINGS.en).sort());
});

test('no text is left empty', () => {
    ['ro', 'en'].forEach((language) => {
        Object.keys(STRINGS[language]).forEach((key) => {
            assert.notEqual(STRINGS[language][key].trim(), '', `${language}: ${key}`);
        });
    });
});

test('Romanian texts are written with comma-below diacritics, never the cedilla ones', () => {
    Object.keys(STRINGS.ro).forEach((key) => {
        assert.doesNotMatch(STRINGS.ro[key], /[şţŞŢ]/, key);
    });
});

/**
 * Every text key that is asked for: whole keys, and the fixed start of keys that are put together.
 * The interface names them in double quotes, the code in calls of t().
 */
function keysInUse() {
    const folder = new URL('../package/contents/', import.meta.url);
    const read = (extension) => readdirSync(folder, { recursive: true })
        .filter((name) => name.endsWith(extension))
        .map((name) => readFileSync(new URL(name, folder), 'utf8'))
        .join('\n');
    const whole = new Set();
    const prefixes = new Set();
    const collect = (pattern, text, into) => {
        let match;

        while ((match = pattern.exec(text)) !== null) {
            into.add(match[1]);
        }
    };

    collect(/"([a-z]+\.[A-Za-z]+)"/g, read('.qml'), whole);
    collect(/\bt\(\w+, '([a-z]+\.[A-Za-z]+)'/g, read('.mjs'), whole);
    collect(/`([a-z]+\.)\$\{/g, read('.qml'), prefixes);

    return { whole: whole, prefixes: prefixes };
}

test('every text the interface asks for exists', () => {
    keysInUse().whole.forEach((key) => {
        assert.ok(key in STRINGS.ro, key);
    });
});

test('no text is kept that the interface never shows', () => {
    const used = keysInUse();

    Object.keys(STRINGS.ro).forEach((key) => {
        const composed = Array.from(used.prefixes).some((prefix) => key.startsWith(prefix));

        assert.ok(used.whole.has(key) || composed, key);
    });
});
