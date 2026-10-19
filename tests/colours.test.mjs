import test from 'node:test';
import assert from 'node:assert/strict';
import { isDark } from '../package/contents/code/colours.mjs';

// Channels as QML gives them, from 0 to 1.
const channels = (hex) => [1, 3, 5].map((start) => parseInt(hex.slice(start, start + 2), 16) / 255);

test('the backgrounds of the dark Plasma themes are dark', () => {
    assert.equal(isDark(...channels('#2a2e32')), true);  // Breeze Dark, window
    assert.equal(isDark(...channels('#20232a')), true);
    assert.equal(isDark(...channels('#000000')), true);
});

test('the backgrounds of the light Plasma themes are not dark', () => {
    assert.equal(isDark(...channels('#eff0f1')), false);  // Breeze, window
    assert.equal(isDark(...channels('#ffffff')), false);
});

test('a saturated colour is judged by how bright it looks, not by its numbers alone', () => {
    // Pure yellow looks bright although blue is zero; pure blue looks dark although it is at full strength.
    assert.equal(isDark(1, 1, 0), false);
    assert.equal(isDark(0, 0, 1), true);
});
