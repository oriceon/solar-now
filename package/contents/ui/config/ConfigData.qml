pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../../code/format.mjs" as Format
import "../../code/i18n.mjs" as I18n

ConfigPage {
    id: page

    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    readonly property var refreshValues: [1, 2, 5, 10, 15, 30]
    readonly property real hintWidth: Kirigami.Units.gridUnit * 22
    readonly property string decimalMark: language === "ro" ? "," : "."

    /** A price, or any other amount, as it is typed: with the decimal mark of the language, and nothing for none. */
    function priceText(value: real): string {
        return value > 0 ? String(value).replace(".", decimalMark) : "";
    }

    // The settings may arrive after the page is built. A field being typed in is left alone:
    // rewriting it would move the cursor and drop a decimal mark that has no digit after it yet.
    onCfg_batteryCapacityChanged: {
        if (!capacityField.activeFocus) {
            capacityField.text = priceText(cfg_batteryCapacity);
        }
    }
    onCfg_priceBuyChanged: {
        if (!buyField.activeFocus) {
            buyField.text = priceText(cfg_priceBuy);
        }
    }
    onCfg_priceSellChanged: {
        if (!sellField.activeFocus) {
            sellField.text = priceText(cfg_priceSell);
        }
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.refresh")
            model: page.refreshValues.map(minutes => `${minutes} min`)
            currentIndex: page.refreshValues.indexOf(page.cfg_refreshMinutes)

            onActivated: index => page.cfg_refreshMinutes = page.refreshValues[index]
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.refreshHint")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.totals")
            checked: page.cfg_showTotals
            text: I18n.t(page.language, "config.totalsShow")

            onToggled: page.cfg_showTotals = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.forecast")
            checked: page.cfg_showForecast
            text: I18n.t(page.language, "config.forecastShow")

            onToggled: page.cfg_showForecast = checked
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.forecastHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.idleBelow")
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                from: 0
                to: 500
                value: page.cfg_idleBelow

                onValueModified: page.cfg_idleBelow = value
            }

            QQC2.Label {
                text: "W"
            }
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.idleBelowHint")
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.lowBattery")
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                from: 0
                to: 100
                stepSize: 5
                value: page.cfg_lowBattery

                onValueModified: page.cfg_lowBattery = value
            }

            QQC2.Label {
                text: "%"
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.batteryCapacity")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: capacityField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                horizontalAlignment: Text.AlignRight
                placeholderText: "0"
                Component.onCompleted: text = page.priceText(page.cfg_batteryCapacity)

                onTextEdited: page.cfg_batteryCapacity = Format.price(text)
            }

            QQC2.Label {
                text: "kWh"
            }
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.batteryReserve")
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                from: 0
                to: 90
                stepSize: 5
                value: page.cfg_batteryReserve

                onValueModified: page.cfg_batteryReserve = value
            }

            QQC2.Label {
                text: "%"
            }
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.batteryHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.notifications")
            Kirigami.FormData.buddyFor: notifyBattery
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                id: notifyBattery

                checked: page.cfg_notifyBattery
                text: I18n.t(page.language, "config.notifyBattery")

                onToggled: page.cfg_notifyBattery = checked
            }

            QQC2.CheckBox {
                checked: page.cfg_notifySilent
                text: I18n.t(page.language, "config.notifySilent")

                onToggled: page.cfg_notifySilent = checked
            }

            QQC2.CheckBox {
                checked: page.cfg_notifyAlerts
                text: I18n.t(page.language, "config.notifyAlerts")

                onToggled: page.cfg_notifyAlerts = checked
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.priceBuy")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: buyField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                horizontalAlignment: Text.AlignRight
                placeholderText: "0"
                Component.onCompleted: text = page.priceText(page.cfg_priceBuy)

                onTextEdited: page.cfg_priceBuy = Format.price(text)
            }

            QQC2.Label {
                text: `${page.cfg_currency} / kWh`
            }
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.priceSell")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: sellField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                horizontalAlignment: Text.AlignRight
                placeholderText: "0"
                Component.onCompleted: text = page.priceText(page.cfg_priceSell)

                onTextEdited: page.cfg_priceSell = Format.price(text)
            }

            QQC2.Label {
                text: `${page.cfg_currency} / kWh`
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: I18n.t(page.language, "config.currency")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            maximumLength: 6
            text: page.cfg_currency

            onTextEdited: page.cfg_currency = text.trim()
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.moneyHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.directions")
            Kirigami.FormData.buddyFor: invertGrid
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                id: invertGrid

                checked: page.cfg_invertGrid
                text: I18n.t(page.language, "config.invertGrid")

                onToggled: page.cfg_invertGrid = checked
            }

            QQC2.CheckBox {
                checked: page.cfg_invertBattery
                text: I18n.t(page.language, "config.invertBattery")

                onToggled: page.cfg_invertBattery = checked
            }

            QQC2.Label {
                Layout.maximumWidth: page.hintWidth
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                text: I18n.t(page.language, "config.directionsHint")
            }
        }
    }
}
