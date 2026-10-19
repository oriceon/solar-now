/** An sRGB channel, 0…1, as the light it gives. */
function linear(channel) {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

/**
 * Whether a colour looks dark: its luminance is under 0.18, the middle grey of the eye (L* = 50).
 * The channels go from 0 to 1, as QML gives them.
 */
export function isDark(red, green, blue) {
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) < 0.18;
}
