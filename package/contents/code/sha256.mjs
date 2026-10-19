// SHA-256 in plain JavaScript: the QML engine has no cryptography, and the
// token endpoint of Deye Cloud takes the password only as its SHA-256.

const ROUND_CONSTANTS = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const INITIAL_STATE = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

function utf8Bytes(text) {
    const bytes = [];

    for (let index = 0; index < text.length; index++) {
        let code = text.charCodeAt(index);
        const low = index + 1 < text.length ? text.charCodeAt(index + 1) : 0;

        // Two surrogates are one character.
        if (code >= 0xd800 && code <= 0xdbff && low >= 0xdc00 && low <= 0xdfff) {
            code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00);
            index++;
        }

        if (code < 0x80) {
            bytes.push(code);
        } else if (code < 0x800) {
            bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
        } else if (code < 0x10000) {
            bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
        } else {
            bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
        }
    }

    return bytes;
}

/** The message, a 1 bit, zeros up to 56 bytes into a block, then the length in bits as 64 bits. */
function padded(bytes) {
    const bits = bytes.length * 8;
    const message = bytes.concat([0x80]);

    while (message.length % 64 !== 56) {
        message.push(0);
    }

    const high = Math.floor(bits / 0x100000000);
    const low = bits >>> 0;

    message.push((high >>> 24) & 0xff, (high >>> 16) & 0xff, (high >>> 8) & 0xff, high & 0xff);
    message.push((low >>> 24) & 0xff, (low >>> 16) & 0xff, (low >>> 8) & 0xff, low & 0xff);

    return message;
}

function rotateRight(word, count) {
    return (word >>> count) | (word << (32 - count));
}

function compress(state, message, offset) {
    const schedule = [];

    for (let index = 0; index < 16; index++) {
        const at = offset + index * 4;

        schedule.push((message[at] << 24) | (message[at + 1] << 16) | (message[at + 2] << 8) | message[at + 3]);
    }

    for (let index = 16; index < 64; index++) {
        const early = schedule[index - 15];
        const late = schedule[index - 2];
        const sigma0 = rotateRight(early, 7) ^ rotateRight(early, 18) ^ (early >>> 3);
        const sigma1 = rotateRight(late, 17) ^ rotateRight(late, 19) ^ (late >>> 10);

        schedule.push((schedule[index - 16] + sigma0 + schedule[index - 7] + sigma1) | 0);
    }

    let a = state[0];
    let b = state[1];
    let c = state[2];
    let d = state[3];
    let e = state[4];
    let f = state[5];
    let g = state[6];
    let h = state[7];

    for (let index = 0; index < 64; index++) {
        const sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
        const choice = (e & f) ^ (~e & g);
        const first = (h + sum1 + choice + ROUND_CONSTANTS[index] + schedule[index]) | 0;
        const sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
        const majority = (a & b) ^ (a & c) ^ (b & c);
        const second = (sum0 + majority) | 0;

        h = g;
        g = f;
        f = e;
        e = (d + first) | 0;
        d = c;
        c = b;
        b = a;
        a = (first + second) | 0;
    }

    return [
        (state[0] + a) | 0,
        (state[1] + b) | 0,
        (state[2] + c) | 0,
        (state[3] + d) | 0,
        (state[4] + e) | 0,
        (state[5] + f) | 0,
        (state[6] + g) | 0,
        (state[7] + h) | 0,
    ];
}

/** SHA-256 of the UTF-8 bytes of `text`, as 64 lowercase hex digits. */
export function sha256Hex(text) {
    const message = padded(utf8Bytes(String(text)));
    let state = INITIAL_STATE;

    for (let offset = 0; offset < message.length; offset += 64) {
        state = compress(state, message, offset);
    }

    return state.map((word) => `0000000${(word >>> 0).toString(16)}`.slice(-8)).join('');
}
