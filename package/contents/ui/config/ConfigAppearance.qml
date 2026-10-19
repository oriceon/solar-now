pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../../code/i18n.mjs" as I18n

ConfigPage {
    id: page

    /** Follows the choice on this page, so the labels switch language before the change is applied. */
    readonly property string language: I18n.resolveLanguage(cfg_language, Qt.locale().uiLanguages)

    /**
     * The options of the ComboBoxes read the same in every language on purpose: a model
     * that changed with the language would make a ComboBox drop its selection.
     */
    readonly property var languageValues: ["auto", "ro", "en"]
    readonly property var fontScaleValues: [90, 100, 110, 125, 140, 160]
    readonly property var tabIds: ["flow", "day", "history", "balance", "alerts", "device"]
    /** What the panel can show, in the order it shows them. */
    readonly property var compactIds: ["battery", "solar", "load", "grid"]

    /** The settings hand over a list that is not a JavaScript array. */
    function compactItems(): var {
        const items = [];

        for (let index = 0; index < cfg_compactItems.length; index++) {
            items.push(String(cfg_compactItems[index]));
        }

        return items;
    }

    /** The settings hand over a list that is not a JavaScript array. */
    function hiddenTabs(): var {
        const hidden = [];

        for (let index = 0; index < cfg_hiddenTabs.length; index++) {
            hidden.push(String(cfg_hiddenTabs[index]));
        }

        return hidden;
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.language")
            model: ["Auto", "Română", "English"]
            currentIndex: page.languageValues.indexOf(page.cfg_language)

            onActivated: index => page.cfg_language = page.languageValues[index]
        }

        QQC2.Label {
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: I18n.t(page.language, "config.languageHint")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.fontSize")
            model: page.fontScaleValues.map(percent => `${percent}%`)
            currentIndex: page.fontScaleValues.indexOf(page.cfg_fontScale)

            onActivated: index => page.cfg_fontScale = page.fontScaleValues[index]
        }

        RowLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.fontFamily")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                // Empty is the font of the Plasma theme.
                text: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : I18n.t(page.language, "config.fontTheme")
            }

            QQC2.Button {
                icon.name: "settings-configure"
                text: I18n.t(page.language, "config.fontChoose")

                onClicked: {
                    fontDialog.selectedFont = Qt.font({ family: page.cfg_fontFamily !== "" ? page.cfg_fontFamily : Kirigami.Theme.defaultFont.family });
                    fontDialog.open();
                }
            }

            QQC2.Button {
                visible: page.cfg_fontFamily !== ""
                icon.name: "edit-undo"
                text: I18n.t(page.language, "config.fontReset")

                onClicked: page.cfg_fontFamily = ""
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.powerUnit")
            Kirigami.FormData.buddyFor: unitAuto
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: unitAuto

                checked: page.cfg_powerUnit === "auto"
                text: I18n.t(page.language, "config.powerUnitAuto")

                onToggled: page.cfg_powerUnit = "auto"
            }

            QQC2.RadioButton {
                checked: page.cfg_powerUnit === "w"
                text: I18n.t(page.language, "config.powerUnitW")

                onToggled: page.cfg_powerUnit = "w"
            }

            QQC2.RadioButton {
                checked: page.cfg_powerUnit === "kw"
                text: I18n.t(page.language, "config.powerUnitKw")

                onToggled: page.cfg_powerUnit = "kw"
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.background")
            Kirigami.FormData.buddyFor: backgroundBlack
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: backgroundBlack

                checked: page.cfg_background === "black"
                text: I18n.t(page.language, "config.backgroundBlack")

                onToggled: page.cfg_background = "black"
            }

            QQC2.RadioButton {
                checked: page.cfg_background === "theme"
                text: I18n.t(page.language, "config.backgroundTheme")

                onToggled: page.cfg_background = "theme"
            }

            QQC2.RadioButton {
                checked: page.cfg_background === "none"
                text: I18n.t(page.language, "config.backgroundNone")

                onToggled: page.cfg_background = "none"
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.animations")
            Kirigami.FormData.buddyFor: animationsFull
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: animationsFull

                checked: page.cfg_animations === "full"
                text: I18n.t(page.language, "config.animationsFull")

                onToggled: page.cfg_animations = "full"
            }

            QQC2.RadioButton {
                checked: page.cfg_animations === "reduced"
                text: I18n.t(page.language, "config.animationsReduced")

                onToggled: page.cfg_animations = "reduced"
            }

            QQC2.RadioButton {
                checked: page.cfg_animations === "off"
                text: I18n.t(page.language, "config.animationsOff")

                onToggled: page.cfg_animations = "off"
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColourChoice {
            Kirigami.FormData.label: I18n.t(page.language, "node.solar")
            colour: page.cfg_colorSolar

            onPicked: colour => page.cfg_colorSolar = colour
        }

        ColourChoice {
            Kirigami.FormData.label: I18n.t(page.language, "node.grid")
            colour: page.cfg_colorGrid

            onPicked: colour => page.cfg_colorGrid = colour
        }

        ColourChoice {
            Kirigami.FormData.label: I18n.t(page.language, "node.battery")
            colour: page.cfg_colorBattery

            onPicked: colour => page.cfg_colorBattery = colour
        }

        ColourChoice {
            Kirigami.FormData.label: I18n.t(page.language, "node.load")
            colour: page.cfg_colorLoad

            onPicked: colour => page.cfg_colorLoad = colour
        }

        QQC2.Button {
            icon.name: "edit-undo"
            text: I18n.t(page.language, "config.colorsReset")

            onClicked: {
                page.cfg_colorSolar = "#ffc53d";
                page.cfg_colorGrid = "#8b9dff";
                page.cfg_colorBattery = "#3ddc97";
                page.cfg_colorLoad = "#4cc9f0";
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.tabs")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.tabIds

                delegate: QQC2.CheckBox {
                    id: tabChoice

                    required property string modelData

                    // The last tab left cannot be turned off.
                    enabled: !checked || page.hiddenTabs().length < page.tabIds.length - 1
                    checked: page.hiddenTabs().indexOf(modelData) === -1
                    text: I18n.t(page.language, `tab.${modelData}`)

                    onToggled: {
                        const others = page.hiddenTabs().filter(id => id !== tabChoice.modelData);

                        page.cfg_hiddenTabs = checked ? others : others.concat([tabChoice.modelData]);
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.compact")
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.compactIds

                delegate: QQC2.CheckBox {
                    id: compactChoice

                    required property string modelData

                    // The panel always shows something.
                    enabled: !checked || page.compactItems().length > 1
                    checked: page.compactItems().indexOf(modelData) !== -1
                    text: I18n.t(page.language, `node.${modelData}`)

                    onToggled: {
                        const chosen = page.compactItems().filter(id => id !== compactChoice.modelData).concat(checked ? [compactChoice.modelData] : []);

                        // Kept in the order the panel shows them, whatever the order of the clicks.
                        page.cfg_compactItems = page.compactIds.filter(id => chosen.indexOf(id) !== -1);
                    }
                }
            }
        }
    }

    // The fonts are listed in a dialog of their own. A ComboBox of the desktop style made a row for
    // every installed font as the page opened and laid them all out again as the list opened, and
    // with a few hundred fonts Plasma froze for seconds, both times.
    QtDialogs.FontDialog {
        id: fontDialog

        title: I18n.t(page.language, "config.fontDialogTitle")
        modality: Qt.WindowModal
        parentWindow: page.Window.window

        onAccepted: page.cfg_fontFamily = selectedFont.family
    }
}
