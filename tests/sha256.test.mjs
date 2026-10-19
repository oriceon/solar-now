import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { sha256Hex } from '../package/contents/code/sha256.mjs';

const reference = (text) => createHash('sha256').update(text, 'utf8').digest('hex');

test('hashes the empty string to the published vector', () => {
    assert.equal(sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
});

test('hashes "abc" to the published vector', () => {
    assert.equal(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});

test('agrees with the reference on every length around the block boundaries', () => {
    [1, 54, 55, 56, 57, 63, 64, 65, 119, 120, 121, 1000].forEach((length) => {
        const text = 'a'.repeat(length);

        assert.equal(sha256Hex(text), reference(text), `length ${length}`);
    });
});

test('hashes the UTF-8 bytes of diacritics, the euro sign and an emoji', () => {
    const password = 'parolă-țș€😀';

    assert.equal(sha256Hex(password), reference(password));
});

test('answers in lowercase hex, as the token endpoint requires', () => {
    assert.match(sha256Hex('Deye'), /^[0-9a-f]{64}$/);
});
