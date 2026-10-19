const MISSING = '–';

const DECIMAL_SEPARATOR = { ro: ',' };

function isMissing(value) {
    return value === null || value === undefined || Number.isNaN(value);
}

function decimal(value, decimals, language) {
    return value.toFixed(decimals).replace('.', DECIMAL_SEPARATOR[language] || '.');
}

/** `unit` is auto, w or kw; auto switches to kilowatts from 1000 W up. */
export function power(watts, unit, language) {
    if (isMissing(watts)) {
        return MISSING;
    }

    const whole = Math.round(watts) || 0;

    if (unit === 'w' || (unit !== 'kw' && Math.abs(whole) < 1000)) {
        return `${whole} W`;
    }

    const kilowatts = watts / 1000;

    return `${decimal(kilowatts, Math.abs(kilowatts) >= 10 ? 1 : 2, language)} kW`;
}

export function energy(kilowattHours, language) {
    if (isMissing(kilowattHours)) {
        return MISSING;
    }

    if (kilowattHours >= 1000) {
        return `${decimal(kilowattHours / 1000, 2, language)} MWh`;
    }

    const decimals = kilowattHours < 10 ? 2 : kilowattHours < 100 ? 1 : 0;

    return `${decimal(kilowattHours, decimals, language)} kWh`;
}

export function percent(value) {
    return isMissing(value) ? MISSING : `${Math.round(value) || 0}%`;
}

export function money(value, currency, language) {
    if (isMissing(value)) {
        return MISSING;
    }

    return `${Math.abs(value) >= 1000 ? Math.round(value) : decimal(value, 2, language)} ${currency}`;
}

/** The price typed in the settings, with a comma or a point; anything that is not a price is 0. */
export function price(text) {
    const value = Number(String(text).trim().replace(',', '.'));

    return String(text).trim() !== '' && Number.isFinite(value) && value > 0 ? value : 0;
}

/** A duration given in hours, as "45 min", "3 h 20 min" or "12 h"; the units read the same in both languages. */
export function duration(hours) {
    if (isMissing(hours)) {
        return MISSING;
    }

    const minutes = Math.round(hours * 60);

    if (minutes >= 99 * 60) {
        return '99 h+';
    }

    if (minutes < 60) {
        return `${minutes} min`;
    }

    // From ten hours up the minutes are noise.
    if (minutes >= 600 || minutes % 60 === 0) {
        return `${Math.round(minutes / 60)} h`;
    }

    return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
}
