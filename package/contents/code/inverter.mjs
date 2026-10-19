// What can be made of the measure points of an inverter. Their names are the ones a three-phase
// hybrid Deye inverter was seen to report; another model may name them otherwise, and a name no
// rule here knows is shown as it comes.

/** Which group a point belongs to; the first rule that matches its key decides. */
const GROUPS = [
    ['generator', /^Gen|Generator/],
    ['battery', /Batter|^SOC$|^BMS|[Cc]harg(e|ing)Energy/],
    ['solar', /PV\d|^PVDaily|Solar|ActiveProduction/],
    ['grid', /Grid|ExternalCT|EnergyPurchased|EnergyBuy|EnergySell/],
    ['load', /^Load|Consumption|UPSLoad/],
    ['inverter', /^AC|Inverter|^RatedPower$|^PowerFactor$|Temperature|^ProtocolVersion$|^MAIN$|^HMI$/],
];

const ORDER = ['solar', 'battery', 'grid', 'load', 'inverter', 'generator', 'other'];

/** The Romanian name of a point, by its key; `$1` stands for the string, the phase or the line the key names. */
const ROMANIAN = [
    [/^DCVoltagePV(\d)$/, 'Tensiune șir $1'],
    [/^DCCurrentPV(\d)$/, 'Curent șir $1'],
    [/^DCPowerPV(\d)$/, 'Putere șir $1'],
    [/^TotalSolarPower$/, 'Putere panouri'],
    [/^PVDailyPowerGenerationActive$/, 'Produs azi de panouri'],
    [/^DailyActiveProduction$/, 'Produs azi'],
    [/^TotalActiveProduction$/, 'Produs în total'],

    [/^BatteryVoltage$/, 'Tensiune baterie'],
    [/^BatteryCurrent(\d)$/, 'Curent baterie $1'],
    [/^BatteryTotalCurrent$/, 'Curent total baterie'],
    [/^BatteryPower$/, 'Putere baterie'],
    [/^SOC$/, 'Încărcare'],
    [/^BatteryRatedCapacity$/, 'Capacitate nominală'],
    [/^TotalChargeEnergy$/, 'Încărcat în total'],
    [/^TotalDischargeEnergy$/, 'Descărcat în total'],
    [/^DailyChargingEnergy$/, 'Încărcat azi'],
    [/^DailyDischargingEnergy$/, 'Descărcat azi'],
    [/^BMSVoltage$/, 'Tensiune după BMS'],
    [/^BMSCurrent$/, 'Curent după BMS'],
    [/^BMSChargeVoltage$/, 'Tensiune de încărcare cerută de BMS'],
    [/^BMSDisChargeVoltage$/, 'Tensiune de descărcare cerută de BMS'],
    [/^BMSSOC$/, 'Încărcare după BMS'],
    [/^Temperature- Battery$/, 'Temperatură baterie'],
    [/^LithiumBatteryVersionNumber$/, 'Versiune baterie cu litiu'],

    [/^GridVoltageL(\d)$/, 'Tensiune rețea L$1'],
    [/^GridCurrentL(\d)$/, 'Curent rețea L$1'],
    [/^GridPowerL(\d)$/, 'Putere rețea L$1'],
    [/^TotalGridPower$/, 'Putere rețea'],
    [/^GridFrequency$/, 'Frecvență rețea'],
    [/^ExternalCT(\d)Power$/, 'Putere pe clește extern $1'],
    [/^TotalExternalCTPower$/, 'Putere pe cleștii externi'],
    [/^TotalGridReactivePower$/, 'Putere reactivă rețea'],
    [/^([ABC])PhaseReactivePowerOfPowerGrid$/, 'Putere reactivă rețea, faza $1'],
    [/^DailyGridFeedIn$/, 'Dat în rețea azi'],
    [/^DailyEnergyPurchased$/, 'Luat din rețea azi'],
    [/^TotalEnergyBuy$/, 'Luat din rețea în total'],
    [/^TotalEnergySell$/, 'Dat în rețea în total'],

    [/^LoadVoltageL(\d)$/, 'Tensiune consum L$1'],
    [/^LoadPowerL(\d)$/, 'Putere consum L$1'],
    [/^LoadPhasePower([ABC])$/, 'Putere consum, faza $1'],
    [/^TotalConsumptionPower$/, 'Putere consum'],
    [/^TotalConsumptionApparentPower$/, 'Putere aparentă consum'],
    [/^DailyConsumption$/, 'Consumat azi'],
    [/^TotalConsumption$/, 'Consumat în total'],
    [/^LoadFrequency$/, 'Frecvență consum'],
    [/^UPSLoadPower$/, 'Putere pe ieșirea UPS'],

    [/^ACVoltageRUA$/, 'Tensiune ieșire L1'],
    [/^ACVoltageSVB$/, 'Tensiune ieșire L2'],
    [/^ACVoltageTWC$/, 'Tensiune ieșire L3'],
    [/^ACCurrentRUA$/, 'Curent ieșire L1'],
    [/^ACCurrentSVB$/, 'Curent ieșire L2'],
    [/^ACCurrentTWC$/, 'Curent ieșire L3'],
    [/^ACOutputFrequencyR$/, 'Frecvență ieșire'],
    [/^InverterOutputPowerL(\d)$/, 'Putere ieșire L$1'],
    [/^TotalInverterOutputPower$/, 'Putere ieșire'],
    [/^Inverter([ABC])PhaseReactivePower$/, 'Putere reactivă ieșire, faza $1'],
    [/^RatedPower$/, 'Putere nominală'],
    [/^PowerFactor$/, 'Factor de putere'],
    [/^AC Temperature$/, 'Temperatură invertor'],
    [/^ProtocolVersion$/, 'Versiune protocol'],
    [/^MAIN$/, 'Versiune placă de bază'],
    [/^HMI$/, 'Versiune afișaj'],

    [/^GenPowerL(\d)$/, 'Putere generator L$1'],
    [/^GenVoltageL(\d)$/, 'Tensiune generator L$1'],
    [/^GeneratorActivePower$/, 'Putere activă generator'],
    [/^TotalGeneratorPower$/, 'Putere generator'],
    [/^TotalGeneratorProduction$/, 'Produs de generator în total'],
];

function groupOf(key) {
    for (let index = 0; index < GROUPS.length; index++) {
        if (GROUPS[index][1].test(key)) {
            return GROUPS[index][0];
        }
    }

    return 'other';
}

function labelOf(point, language) {
    if (language !== 'ro') {
        return point.label;
    }

    for (let index = 0; index < ROMANIAN.length; index++) {
        if (ROMANIAN[index][0].test(point.key)) {
            return point.key.replace(ROMANIAN[index][0], ROMANIAN[index][1]);
        }
    }

    return point.label;
}

/**
 * The measure points of a device, sorted into what they are about.
 *
 * @param points   the points of a device of parseMeasurePoints() in code/deye.mjs
 * @returns `{ id, points }` of every group that has any, in the order solar, battery, grid, load,
 *          inverter, generator, other; the points carry a name in `language` where one is known
 */
export function groupPoints(points, language) {
    const byGroup = {};

    points.forEach((point) => {
        const id = groupOf(point.key);

        byGroup[id] = byGroup[id] || [];
        byGroup[id].push({ key: point.key, label: labelOf(point, language), value: point.value, unit: point.unit });
    });

    return ORDER.filter((id) => byGroup[id] !== undefined).map((id) => ({ id: id, points: byGroup[id] }));
}

function valueOf(points, key) {
    for (let index = 0; index < points.length; index++) {
        if (points[index].key === key) {
            const value = Number(points[index].value);

            return Number.isFinite(value) ? value : null;
        }
    }

    return null;
}

/**
 * The nominal voltage of a battery from the one it measures now, which moves with how full it is:
 * a 12, 24 or 48 V lithium battery is 12.8, 25.6 or 51.2 V whatever its charge. A battery of any
 * other kind keeps the voltage it reports.
 */
function nominalVoltage(measured) {
    const classes = [[10, 16, 12.8], [20, 31, 25.6], [40, 62, 51.2]];

    for (let index = 0; index < classes.length; index++) {
        if (measured >= classes[index][0] && measured <= classes[index][1]) {
            return classes[index][2];
        }
    }

    return measured;
}

/**
 * The capacity of the battery in kWh, from the first device that reports its rated ampere-hours and
 * its voltage; null when none does.
 *
 * @param devices parseMeasurePoints() of code/deye.mjs
 */
export function batteryCapacity(devices) {
    for (let index = 0; index < devices.length; index++) {
        const rated = valueOf(devices[index].points, 'BatteryRatedCapacity');
        const voltage = valueOf(devices[index].points, 'BatteryVoltage');

        if (rated !== null && voltage !== null && rated > 0 && voltage > 0) {
            return Number((rated * nominalVoltage(voltage) / 1000).toFixed(1));
        }
    }

    return null;
}
