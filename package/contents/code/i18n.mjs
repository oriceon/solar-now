export const LANGUAGES = ['ro', 'en'];

const FALLBACK_LANGUAGE = 'en';

const MONTHS_LONG = {
    ro: ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'],
    en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
};

const MONTHS_SHORT = {
    ro: ['ian.', 'feb.', 'mar.', 'apr.', 'mai', 'iun.', 'iul.', 'aug.', 'sept.', 'oct.', 'nov.', 'dec.'],
    en: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
};

export const STRINGS = {
    ro: {
        'node.solar': 'Panouri',
        'node.grid': 'Rețea',
        'node.battery': 'Baterie',
        'node.load': 'Consum',
        'node.inverter': 'Invertor',

        'grid.import': 'Din rețea',
        'grid.export': 'În rețea',
        'battery.left': 'încă {time}',
        'battery.untilFull': 'plină în {time}',
        'battery.charge': 'Se încarcă',
        'battery.discharge': 'Se descarcă',

        'tab.flow': 'Flux',
        'tab.day': 'Zi',
        'tab.history': 'Istoric',
        'tab.balance': 'Bilanț',
        'tab.alerts': 'Alerte',
        'tab.device': 'Invertor',

        'tabstate.loading': 'Se încarcă…',
        'tabstate.failed': 'Datele nu au putut fi încărcate.',
        'tabstate.empty': 'Nu există date pentru această perioadă.',

        'series.generation': 'Producție',
        'series.consumption': 'Consum',
        'series.grid': 'Rețea',
        'series.battery': 'Baterie',
        'series.soc': 'Baterie %',
        'day.peakGeneration': 'Vârf de producție {value} la {time}',
        'day.peakConsumption': 'Vârf de consum {value} la {time}',
        'day.signs': 'Rețea: peste zero se cumpără, sub zero se vinde. Baterie: peste zero se descarcă, sub zero se încarcă.',

        'scale.month': 'Lună',
        'scale.year': 'An',
        'scale.total': 'Total',
        'energy.generation': 'Produs',
        'energy.discharge': 'Din baterie',
        'energy.purchase': 'Din rețea',
        'energy.consumption': 'Consumat',
        'energy.charge': 'În baterie',
        'energy.feedIn': 'În rețea',
        'history.hint': 'Deasupra liniei de zero, de unde a venit energia; dedesubt, unde s-a dus.',

        'balance.consumption': 'Consum',
        'balance.production': 'Producție',
        'balance.solar': 'Din panouri',
        'balance.battery': 'Din baterie',
        'balance.grid': 'Din rețea',
        'balance.direct': 'Consumat direct',
        'balance.charge': 'În baterie',
        'balance.export': 'În rețea',
        'balance.selfSufficiency': 'Autonomie',
        'balance.selfSufficiencyHint': 'din consum nu a venit din rețea',
        'balance.selfConsumption': 'Autoconsum',
        'balance.selfConsumptionHint': 'din producție a rămas în casă',

        'alerts.none': 'Nicio alertă în ultimele {days} de zile.',
        'alerts.open': 'Activă',
        'alerts.notice': 'Notificare',
        'alerts.warning': 'Avertizare',
        'alerts.failure': 'Defect',

        'device.none': 'Niciun dispozitiv al stației nu raportează date.',
        'device.read': 'citit la {time}',
        'device.hint': 'Valorile vin direct de la invertor, așa cum le dă Deye Cloud.',

        'devicegroup.solar': 'Panouri',
        'devicegroup.battery': 'Baterie',
        'devicegroup.grid': 'Rețea',
        'devicegroup.load': 'Consum',
        'devicegroup.inverter': 'Invertor',
        'devicegroup.generator': 'Generator',
        'devicegroup.other': 'Altele',

        'forecast.title': 'Estimare de producție',
        'forecast.today': 'azi circa {value}',
        'forecast.tomorrow': 'mâine circa {value}',
        'forecast.source': 'Radiația solară de la {source}',

        'money.saved': 'Economisit',
        'money.earned': 'Încasat',
        'money.paid': 'Plătit',

        'notify.batteryTitle': '{station}: baterie scăzută',
        'notify.batteryText': 'Bateria a coborât la {soc}.',
        'notify.silentTitle': '{station}: stația nu mai trimite date',
        'notify.silentText': 'Ultimele date sunt din {time}.',
        'notify.alertTitle': '{station}: alertă nouă',

        'period.today': 'Azi',
        'period.allYears': 'Toți anii',

        'header.updated': 'Actualizat la {time}',
        'header.stale': 'Ultimele date: {time}',
        'header.refresh': 'Actualizează',

        'totals.generation': 'Produs azi',
        'totals.consumption': 'Consumat azi',
        'totals.purchase': 'Luat din rețea',
        'totals.feedIn': 'Dat în rețea',

        'state.setupTitle': 'Conectează widgetul la Deye Cloud',
        'state.setupText': 'Completează în setări AppId, AppSecret și contul tău Deye Cloud.',
        'state.openSettings': 'Deschide setările',
        'state.loading': 'Se încarcă datele…',
        'state.error': 'Datele nu au putut fi încărcate.',
        'state.login': 'Sesiunea a expirat. Scrie din nou parola în setări.',
        'state.credentials': 'Deye Cloud a respins datele de autentificare. Verifică-le în setări.',
        'state.rate': 'Prea multe cereri către Deye Cloud. Se reîncearcă mai târziu.',
        'state.noStation': 'Alege o stație în setări.',
        'state.retry': 'Încearcă din nou',

        'tooltip.setup': 'Neconectat la Deye Cloud',

        'config.account': 'Cont',
        'config.data': 'Date',
        'config.appearance': 'Aspect',

        'config.region': 'Centru de date',
        'config.regionEu': 'Europa, Africa, Asia-Pacific',
        'config.regionUs': 'America de Nord și de Sud',
        'config.regionIndia': 'India',
        'config.regionCustom': 'Altă adresă',
        'config.regionHint': 'Același centru de date pe care l-ai ales la crearea contului Deye Cloud.',
        'config.customUrl': 'Adresa serverului',
        'config.appId': 'AppId',
        'config.appSecret': 'AppSecret',
        'config.portalHint': 'Le primești pe developer.deyecloud.com, după ce creezi o aplicație.',
        'config.login': 'Email sau utilizator',
        'config.password': 'Parolă',
        'config.passwordHint': 'Parola pleacă o singură dată, ca amprentă SHA-256, ca să obțină tokenul.',
        'config.passwordKept': 'Parola este ținută minte. Scrie-o doar dacă ai schimbat-o.',
        'config.remember': 'Ține minte parola',
        'config.rememberHint': 'Tokenul expiră după 60 de zile. Cu parola ținută minte, widgetul îl reînnoiește singur; altfel îți cere parola din nou. Se păstrează amprenta SHA-256 a parolei, necriptată, în fișierul de setări Plasma. Pentru Deye Cloud amprenta ține loc de parolă: cine citește fișierul poate cere un token.',
        'config.companyId': 'Id companie',
        'config.companyHint': 'Doar pentru conturile business. Lasă gol pentru un cont personal.',
        'config.connect': 'Conectează',
        'config.connecting': 'Se conectează…',
        'config.connected': 'Conectat. Tokenul este valabil până la {date}.',
        'config.notConnected': 'Neconectat.',
        'config.fillAll': 'Completează AppId, AppSecret, contul și parola.',
        'config.connectFailed': 'Conectarea a eșuat: {reason}',
        'config.noAnswer': 'serverul nu a răspuns',
        'config.tooMany': 'prea multe cereri, încearcă mai târziu',
        'config.unexpected': 'răspuns neașteptat de la server',
        'config.station': 'Stație',
        'config.stationNone': 'Nicio stație aleasă',
        'config.noStations': 'Contul nu are nicio stație.',
        'config.applyHint': 'Apasă „Aplică” ca widgetul să folosească datele noi.',

        'config.refresh': 'Actualizare la',
        'config.refreshHint': 'Deye reîmprospătează datele stației cel mult o dată la 5 minute; mai des s-ar primi aceleași date.',
        'config.totals': 'Totalurile zilei',
        'config.totalsShow': 'Arată ce s-a produs și s-a consumat azi',
        'config.idleBelow': 'Flux oprit sub',
        'config.idleBelowHint': 'Sub această putere, linia rămâne fără mișcare.',
        'config.lowBattery': 'Baterie scăzută sub',
        'config.forecast': 'Estimare',
        'config.forecastShow': 'Arată cât se așteaptă să producă panourile azi și mâine',
        'config.forecastHint': 'Se calculează din radiația solară prognozată de Open-Meteo și din ce au produs panourile în ultimele două săptămâni. Către Open-Meteo pleacă doar coordonatele stației, rotunjite la circa un kilometru.',
        'config.batteryCapacity': 'Capacitatea bateriei',
        'config.batteryReserve': 'Rezerva bateriei',
        'config.batteryHint': 'Din ele se calculează cât mai ține bateria și în cât timp se umple. Capacitatea lăsată goală se ia de la invertor. Rezerva este procentul sub care invertorul nu mai descarcă bateria.',
        'config.notifications': 'Notificări',
        'config.notifyBattery': 'Când bateria scade sub prag',
        'config.notifySilent': 'Când stația nu mai trimite date',
        'config.notifyAlerts': 'Când stația dă o alertă nouă',
        'config.priceBuy': 'Preț la cumpărare',
        'config.priceSell': 'Preț la vânzare',
        'config.currency': 'Monedă',
        'config.moneyHint': 'Cu prețurile completate, Istoric și Bilanț arată cât ai economisit, cât ai încasat și cât ai plătit. Este o estimare: nu ține cont de abonament, taxe sau compensare.',
        'config.directions': 'Sensul săgeților',
        'config.invertGrid': 'Inversează sensul rețelei',
        'config.invertBattery': 'Inversează sensul bateriei',
        'config.directionsHint': 'Bifează dacă săgețile merg invers față de aplicația Deye Cloud.',

        'config.language': 'Limbă',
        'config.languageHint': '„Auto” folosește limba interfeței Plasma; engleza, dacă aceea nu e nici română, nici engleză.',
        'config.fontSize': 'Mărimea textului',
        'config.fontFamily': 'Font',
        'config.powerUnit': 'Putere în',
        'config.powerUnitAuto': 'W, iar de la 1000 W în sus kW',
        'config.powerUnitW': 'Mereu W',
        'config.powerUnitKw': 'Mereu kW',
        'config.background': 'Fundal',
        'config.backgroundBlack': 'Negru',
        'config.backgroundTheme': 'Al temei Plasma',
        'config.backgroundNone': 'Transparent',
        'config.animations': 'Animații',
        'config.animationsFull': 'Complete: linii, puncte și iconițe',
        'config.animationsReduced': 'Reduse: doar punctele de pe linii',
        'config.animationsOff': 'Oprite',
        'config.colorsReset': 'Culorile implicite',
        'config.tabs': 'Taburi',
        'config.compact': 'În panou',
    },
    en: {
        'node.solar': 'Solar',
        'node.grid': 'Grid',
        'node.battery': 'Battery',
        'node.load': 'Load',
        'node.inverter': 'Inverter',

        'grid.import': 'From grid',
        'grid.export': 'To grid',
        'battery.left': '{time} left',
        'battery.untilFull': 'full in {time}',
        'battery.charge': 'Charging',
        'battery.discharge': 'Discharging',

        'tab.flow': 'Flow',
        'tab.day': 'Day',
        'tab.history': 'History',
        'tab.balance': 'Balance',
        'tab.alerts': 'Alerts',
        'tab.device': 'Inverter',

        'tabstate.loading': 'Loading…',
        'tabstate.failed': 'The data could not be loaded.',
        'tabstate.empty': 'There is no data for this period.',

        'series.generation': 'Production',
        'series.consumption': 'Consumption',
        'series.grid': 'Grid',
        'series.battery': 'Battery',
        'series.soc': 'Battery %',
        'day.peakGeneration': 'Peak production {value} at {time}',
        'day.peakConsumption': 'Peak consumption {value} at {time}',
        'day.signs': 'Grid: above zero is bought, below zero is sold. Battery: above zero it discharges, below zero it charges.',

        'scale.month': 'Month',
        'scale.year': 'Year',
        'scale.total': 'Total',
        'energy.generation': 'Produced',
        'energy.discharge': 'From battery',
        'energy.purchase': 'From grid',
        'energy.consumption': 'Used',
        'energy.charge': 'To battery',
        'energy.feedIn': 'To grid',
        'history.hint': 'Above the zero line, where the energy came from; below it, where it went.',

        'balance.consumption': 'Consumption',
        'balance.production': 'Production',
        'balance.solar': 'From panels',
        'balance.battery': 'From battery',
        'balance.grid': 'From grid',
        'balance.direct': 'Used directly',
        'balance.charge': 'To battery',
        'balance.export': 'To grid',
        'balance.selfSufficiency': 'Self-sufficiency',
        'balance.selfSufficiencyHint': 'of the consumption did not come from the grid',
        'balance.selfConsumption': 'Self-consumption',
        'balance.selfConsumptionHint': 'of the production stayed in the house',

        'alerts.none': 'No alerts in the last {days} days.',
        'alerts.open': 'Open',
        'alerts.notice': 'Notice',
        'alerts.warning': 'Warning',
        'alerts.failure': 'Failure',

        'device.none': 'No device of the station reports any data.',
        'device.read': 'read at {time}',
        'device.hint': 'The values come straight from the inverter, as Deye Cloud gives them.',

        'devicegroup.solar': 'Panels',
        'devicegroup.battery': 'Battery',
        'devicegroup.grid': 'Grid',
        'devicegroup.load': 'Load',
        'devicegroup.inverter': 'Inverter',
        'devicegroup.generator': 'Generator',
        'devicegroup.other': 'Other',

        'forecast.title': 'Expected production',
        'forecast.today': 'about {value} today',
        'forecast.tomorrow': 'about {value} tomorrow',
        'forecast.source': 'Solar radiation from {source}',

        'money.saved': 'Saved',
        'money.earned': 'Earned',
        'money.paid': 'Paid',

        'notify.batteryTitle': '{station}: low battery',
        'notify.batteryText': 'The battery is down to {soc}.',
        'notify.silentTitle': '{station}: the station stopped reporting',
        'notify.silentText': 'The last data is from {time}.',
        'notify.alertTitle': '{station}: new alert',

        'period.today': 'Today',
        'period.allYears': 'All years',

        'header.updated': 'Updated at {time}',
        'header.stale': 'Last data: {time}',
        'header.refresh': 'Refresh',

        'totals.generation': 'Produced today',
        'totals.consumption': 'Used today',
        'totals.purchase': 'From grid',
        'totals.feedIn': 'To grid',

        'state.setupTitle': 'Connect the widget to Deye Cloud',
        'state.setupText': 'Fill in the AppId, the AppSecret and your Deye Cloud account in the settings.',
        'state.openSettings': 'Open settings',
        'state.loading': 'Loading the data…',
        'state.error': 'The data could not be loaded.',
        'state.login': 'The session has expired. Type the password again in the settings.',
        'state.credentials': 'Deye Cloud rejected the credentials. Check them in the settings.',
        'state.rate': 'Too many requests to Deye Cloud. Trying again later.',
        'state.noStation': 'Pick a station in the settings.',
        'state.retry': 'Try again',

        'tooltip.setup': 'Not connected to Deye Cloud',

        'config.account': 'Account',
        'config.data': 'Data',
        'config.appearance': 'Appearance',

        'config.region': 'Data centre',
        'config.regionEu': 'Europe, Africa, Asia-Pacific',
        'config.regionUs': 'North and South America',
        'config.regionIndia': 'India',
        'config.regionCustom': 'Another address',
        'config.regionHint': 'The data centre you chose when you created the Deye Cloud account.',
        'config.customUrl': 'Server address',
        'config.appId': 'AppId',
        'config.appSecret': 'AppSecret',
        'config.portalHint': 'You get them on developer.deyecloud.com, after creating an application.',
        'config.login': 'Email or username',
        'config.password': 'Password',
        'config.passwordHint': 'The password is sent once, as its SHA-256, to obtain the token.',
        'config.passwordKept': 'The password is remembered. Type it only if you changed it.',
        'config.remember': 'Remember the password',
        'config.rememberHint': 'The token expires after 60 days. With the password remembered, the widget renews it by itself; otherwise it asks for the password again. The SHA-256 of the password is kept unencrypted in the Plasma settings file. Deye Cloud accepts it in place of the password: whoever reads the file can ask for a token.',
        'config.companyId': 'Company id',
        'config.companyHint': 'Only for business accounts. Leave empty for a personal account.',
        'config.connect': 'Connect',
        'config.connecting': 'Connecting…',
        'config.connected': 'Connected. The token is valid until {date}.',
        'config.notConnected': 'Not connected.',
        'config.fillAll': 'Fill in the AppId, the AppSecret, the account and the password.',
        'config.connectFailed': 'Connecting failed: {reason}',
        'config.noAnswer': 'the server did not answer',
        'config.tooMany': 'too many requests, try again later',
        'config.unexpected': 'unexpected answer from the server',
        'config.station': 'Station',
        'config.stationNone': 'No station picked',
        'config.noStations': 'The account has no station.',
        'config.applyHint': 'Press “Apply” for the widget to use the new data.',

        'config.refresh': 'Refresh every',
        'config.refreshHint': 'Deye refreshes the data of a station at most once every 5 minutes; asking more often would bring the same data.',
        'config.totals': 'Totals of the day',
        'config.totalsShow': 'Show what was produced and used today',
        'config.idleBelow': 'No flow below',
        'config.idleBelowHint': 'Below this power the line stays still.',
        'config.lowBattery': 'Low battery below',
        'config.forecast': 'Estimate',
        'config.forecastShow': 'Show what the panels are expected to produce today and tomorrow',
        'config.forecastHint': 'Worked out from the solar radiation Open-Meteo forecasts and from what the panels produced in the last two weeks. Only the place of the station goes to Open-Meteo, rounded to about a kilometre.',
        'config.batteryCapacity': 'Battery capacity',
        'config.batteryReserve': 'Battery reserve',
        'config.batteryHint': 'They tell how long the battery lasts and how soon it is full. A capacity left empty is taken from the inverter. The reserve is the percent under which the inverter no longer draws from the battery.',
        'config.notifications': 'Notifications',
        'config.notifyBattery': 'When the battery falls under the threshold',
        'config.notifySilent': 'When the station stops reporting',
        'config.notifyAlerts': 'When the station raises a new alert',
        'config.priceBuy': 'Price when buying',
        'config.priceSell': 'Price when selling',
        'config.currency': 'Currency',
        'config.moneyHint': 'With the prices filled in, History and Balance show what you saved, earned and paid. It is an estimate: it leaves out standing charges, taxes and netting.',
        'config.directions': 'Direction of the arrows',
        'config.invertGrid': 'Reverse the direction of the grid',
        'config.invertBattery': 'Reverse the direction of the battery',
        'config.directionsHint': 'Tick it if the arrows run the other way than in the Deye Cloud app.',

        'config.language': 'Language',
        'config.languageHint': '“Auto” uses the language of the Plasma interface; English when that is neither Romanian nor English.',
        'config.fontSize': 'Text size',
        'config.fontFamily': 'Font',
        'config.powerUnit': 'Power in',
        'config.powerUnitAuto': 'W, and kW from 1000 W up',
        'config.powerUnitW': 'Always W',
        'config.powerUnitKw': 'Always kW',
        'config.background': 'Background',
        'config.backgroundBlack': 'Black',
        'config.backgroundTheme': 'Of the Plasma theme',
        'config.backgroundNone': 'Transparent',
        'config.animations': 'Animations',
        'config.animationsFull': 'Full: lines, dots and icons',
        'config.animationsReduced': 'Reduced: only the dots on the lines',
        'config.animationsOff': 'Off',
        'config.colorsReset': 'Default colours',
        'config.tabs': 'Tabs',
        'config.compact': 'In the panel',
    },
};

function supported(language) {
    return LANGUAGES.indexOf(language) !== -1 ? language : FALLBACK_LANGUAGE;
}

/**
 * Picks the language of the widget. "auto" follows the language of the Plasma interface,
 * `uiLanguages` being the system's list of them in order of preference ("en-US", "ro_RO"…):
 * the first one the widget speaks, else English. The regional formats do not count.
 */
export function resolveLanguage(setting, uiLanguages) {
    if (LANGUAGES.indexOf(setting) !== -1) {
        return setting;
    }

    const spoken = (uiLanguages || []).map((tag) => String(tag).slice(0, 2).toLowerCase()).filter((language) => LANGUAGES.indexOf(language) !== -1);

    return spoken.length > 0 ? spoken[0] : FALLBACK_LANGUAGE;
}

export function t(language, key, parameters) {
    const text = STRINGS[supported(language)][key];

    if (text === undefined) {
        return key;
    }

    return text.replace(/\{(\w+)\}/g, (placeholder, name) => (parameters && name in parameters ? parameters[name] : placeholder));
}

/** The name of a period of `scale` (month, year or total): "octombrie 2026", "2026", "Toți anii". */
export function periodLabel(language, scale, anchor) {
    if (scale === 'month') {
        return `${MONTHS_LONG[supported(language)][Number(anchor.slice(5, 7)) - 1]} ${anchor.slice(0, 4)}`;
    }

    return scale === 'year' ? anchor : t(language, 'period.allYears');
}

/** The name of the day `date` (yyyy-MM-dd): "Azi" for `today`, "12 octombrie 2026" otherwise. */
export function dayLabel(language, date, today) {
    if (date === today) {
        return t(language, 'period.today');
    }

    return `${Number(date.slice(8, 10))} ${MONTHS_LONG[supported(language)][Number(date.slice(5, 7)) - 1]} ${date.slice(0, 4)}`;
}

/** What stands under a bar of the history: the day of the month, the short name of the month, or the year. */
export function barLabel(language, scale, key) {
    return scale === 'year' ? MONTHS_SHORT[supported(language)][key - 1] : String(key);
}
