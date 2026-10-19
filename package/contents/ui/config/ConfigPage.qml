import QtQuick
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

/**
 * A page of the settings dialog. Plasma hands every setting of config/main.xml, and its default, to
 * every page, and on Apply writes them all back from the page on show. A page without one of them
 * gets a line in the journal, so they are all declared here.
 *
 * The widget writes some settings itself, also while the dialog is open: a renewed token, the
 * station picked in the header. Before Plasma writes back, each setting the page has not changed
 * takes its current value, so that Apply never brings back an old token.
 */
KCM.SimpleKCM {
    id: settingsPage

    property string cfg_region
    property string cfg_regionDefault
    property string cfg_customUrl
    property string cfg_customUrlDefault
    property string cfg_appId
    property string cfg_appIdDefault
    property string cfg_appSecret
    property string cfg_appSecretDefault
    property string cfg_login
    property string cfg_loginDefault
    property string cfg_passwordHash
    property string cfg_passwordHashDefault
    property bool cfg_rememberPassword
    property bool cfg_rememberPasswordDefault
    property string cfg_companyId
    property string cfg_companyIdDefault
    property string cfg_accessToken
    property string cfg_accessTokenDefault
    property real cfg_tokenExpiresAt
    property real cfg_tokenExpiresAtDefault
    property string cfg_stationId
    property string cfg_stationIdDefault
    property string cfg_stationName
    property string cfg_stationNameDefault
    property int cfg_refreshMinutes
    property int cfg_refreshMinutesDefault
    property bool cfg_showTotals
    property bool cfg_showTotalsDefault
    property int cfg_idleBelow
    property int cfg_idleBelowDefault
    property int cfg_lowBattery
    property int cfg_lowBatteryDefault
    property real cfg_batteryCapacity
    property real cfg_batteryCapacityDefault
    property int cfg_batteryReserve
    property int cfg_batteryReserveDefault
    property bool cfg_showForecast
    property bool cfg_showForecastDefault
    property string cfg_forecastHost
    property string cfg_forecastHostDefault
    property bool cfg_notifyBattery
    property bool cfg_notifyBatteryDefault
    property bool cfg_notifySilent
    property bool cfg_notifySilentDefault
    property bool cfg_notifyAlerts
    property bool cfg_notifyAlertsDefault
    property real cfg_priceBuy
    property real cfg_priceBuyDefault
    property real cfg_priceSell
    property real cfg_priceSellDefault
    property string cfg_currency
    property string cfg_currencyDefault
    property bool cfg_invertGrid
    property bool cfg_invertGridDefault
    property bool cfg_invertBattery
    property bool cfg_invertBatteryDefault
    property string cfg_language
    property string cfg_languageDefault
    property int cfg_fontScale
    property int cfg_fontScaleDefault
    property string cfg_fontFamily
    property string cfg_fontFamilyDefault
    property string cfg_powerUnit
    property string cfg_powerUnitDefault
    property string cfg_background
    property string cfg_backgroundDefault
    property string cfg_animations
    property string cfg_animationsDefault
    property string cfg_colorSolar
    property string cfg_colorSolarDefault
    property string cfg_colorGrid
    property string cfg_colorGridDefault
    property string cfg_colorBattery
    property string cfg_colorBatteryDefault
    property string cfg_colorLoad
    property string cfg_colorLoadDefault
    property var cfg_hiddenTabs: []
    property var cfg_hiddenTabsDefault: []
    property var cfg_compactItems: []
    property var cfg_compactItemsDefault: []

    /** The settings as the page holds them since it opened, or since the last Apply. */
    property var settingsAtStart: ({})

    /** The settings this page has, with the values it holds now. */
    function heldSettings(): var {
        const held = {};

        Plasmoid.configuration.keys().forEach(key => {
            if (!key.endsWith("Default") && `cfg_${key}` in settingsPage) {
                held[key] = settingsPage[`cfg_${key}`];
            }
        });

        return held;
    }

    /** Called by Plasma right before it writes the settings of the page. */
    function saveConfig(): void {
        const held = heldSettings();

        Object.keys(held).forEach(key => {
            if (String(held[key]) === String(settingsAtStart[key])) {
                settingsPage[`cfg_${key}`] = Plasmoid.configuration[key];
            }
        });

        settingsAtStart = heldSettings();
    }

    Component.onCompleted: settingsAtStart = heldSettings()
}
