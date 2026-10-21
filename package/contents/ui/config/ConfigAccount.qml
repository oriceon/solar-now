pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../../code/deye.mjs" as Deye
import "../../code/i18n.mjs" as I18n
import "../../code/sha256.mjs" as Sha256
import ".." as Ui

ConfigPage {
    id: page

    readonly property string language: I18n.resolveLanguage(Plasmoid.configuration.language, Qt.locale().uiLanguages)
    readonly property var regionValues: ["eu", "us", "india", "custom"]
    readonly property real hintWidth: Kirigami.Units.gridUnit * 22
    /** parseStations() of code/deye.mjs; empty until the account was asked for them. */
    property var stations: []
    /** True once the stations were asked for, by the page itself on opening or by the Connect button. */
    property bool stationsAsked: false
    property bool busy: false
    /** How the last attempt to connect ended, in the language of the page; empty before the first. */
    property string message: ""
    property bool failed: false
    readonly property bool connected: cfg_accessToken !== "" && cfg_tokenExpiresAt > Date.now() / 1000

    readonly property Ui.ApiClient client: Ui.ApiClient {}

    function report(text: string, isFailure: bool): void {
        busy = false;
        failed = isFailure;
        message = text;
    }

    /** What went wrong, in words: the ones of the API when it gave any. */
    function reason(response: var): string {
        if (response.message !== "") {
            return response.message;
        }

        return I18n.t(language, response.kind === "network" ? "config.noAnswer" : response.kind === "rate" ? "config.tooMany" : "config.unexpected");
    }

    /**
     * Asks for a token with the password just typed, or with the remembered one, then for the
     * stations of the account. A token that is still valid is enough to ask for the stations alone.
     */
    function connect(): void {
        stationsAsked = true;

        const typed = passwordField.text;
        const hash = typed !== "" ? Sha256.sha256Hex(typed) : cfg_passwordHash;

        if (cfg_appId.trim() === "" || cfg_appSecret === "" || cfg_login.trim() === "" || (hash === "" && !connected)) {
            report(I18n.t(language, "config.fillAll"), true);

            return;
        }

        busy = true;
        message = "";

        if (hash === "") {
            loadStations(cfg_accessToken, false);

            return;
        }

        const account = {
            region: cfg_region,
            customUrl: cfg_customUrl,
            appId: cfg_appId.trim(),
            appSecret: cfg_appSecret,
            login: cfg_login,
            passwordHash: hash,
            companyId: cfg_companyId,
        };

        client.post(Deye.tokenRequest(account), "", response => {
            const token = response.ok ? Deye.parseToken(response.data, Date.now() / 1000) : null;

            if (token === null) {
                page.report(I18n.t(page.language, "config.connectFailed", { reason: page.reason(response) }), true);

                return;
            }

            page.cfg_accessToken = token.accessToken;
            page.cfg_tokenExpiresAt = token.expiresAt;
            page.cfg_passwordHash = page.cfg_rememberPassword ? hash : "";
            passwordField.text = "";
            page.loadStations(token.accessToken, false);
        });
    }

    /**
     * Settings that already hold a valid token list the stations as soon as they open, so that
     * another one can be picked without connecting again.
     */
    function listStationsOnOpen(): void {
        if (stationsAsked || !connected) {
            return;
        }

        stationsAsked = true;
        loadStations(cfg_accessToken, true);
    }

    /** `quiet` only fills the list: it picks nothing, and a failure leaves the page as it was. */
    function loadStations(token: string, quiet: bool): void {
        client.post(Deye.stationListRequest(cfg_region, cfg_customUrl), token, response => {
            if (quiet) {
                page.stations = response.ok ? Deye.parseStations(response.data) : [];

                return;
            }

            if (!response.ok) {
                page.report(I18n.t(page.language, "config.connectFailed", { reason: page.reason(response) }), true);

                return;
            }

            page.stations = Deye.parseStations(response.data);

            if (page.stations.length === 0) {
                page.report(I18n.t(page.language, "config.noStations"), true);

                return;
            }

            // The station already picked stays, as long as the account still has it.
            const kept = page.stations.filter(station => station.id === page.cfg_stationId);

            page.pick(kept.length > 0 ? kept[0] : page.stations[0]);
            page.report(I18n.t(page.language, "config.applyHint"), false);
        });
    }

    function pick(station: var): void {
        cfg_stationId = station.id;
        cfg_stationName = station.name;
    }

    // Plasma may hand over the settings only after the page is built; `connected` follows them either way.
    onConnectedChanged: listStationsOnOpen()
    Component.onCompleted: listStationsOnOpen()

    Kirigami.FormLayout {
        ColumnLayout {
            Kirigami.FormData.label: I18n.t(page.language, "config.region")
            Kirigami.FormData.buddyFor: regionEu
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: regionEu

                checked: page.cfg_region === "eu"
                text: I18n.t(page.language, "config.regionEu")

                onToggled: page.cfg_region = "eu"
            }

            QQC2.RadioButton {
                checked: page.cfg_region === "us"
                text: I18n.t(page.language, "config.regionUs")

                onToggled: page.cfg_region = "us"
            }

            QQC2.RadioButton {
                checked: page.cfg_region === "india"
                text: I18n.t(page.language, "config.regionIndia")

                onToggled: page.cfg_region = "india"
            }

            QQC2.RadioButton {
                checked: page.cfg_region === "custom"
                text: I18n.t(page.language, "config.regionCustom")

                onToggled: page.cfg_region = "custom"
            }

            QQC2.Label {
                Layout.maximumWidth: page.hintWidth
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                text: I18n.t(page.language, "config.regionHint")
            }
        }

        QQC2.TextField {
            Kirigami.FormData.label: I18n.t(page.language, "config.customUrl")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            visible: page.cfg_region === "custom"
            placeholderText: "https://"
            text: page.cfg_customUrl

            onTextEdited: page.cfg_customUrl = text
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            Kirigami.FormData.label: I18n.t(page.language, "config.appId")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: page.cfg_appId

            onTextEdited: page.cfg_appId = text.trim()
        }

        Kirigami.PasswordField {
            Kirigami.FormData.label: I18n.t(page.language, "config.appSecret")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: page.cfg_appSecret

            onTextEdited: page.cfg_appSecret = text.trim()
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.portalHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            Kirigami.FormData.label: I18n.t(page.language, "config.login")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            text: page.cfg_login

            onTextEdited: page.cfg_login = text
        }

        Kirigami.PasswordField {
            id: passwordField

            objectName: "passwordField"
            Kirigami.FormData.label: I18n.t(page.language, "config.password")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16

            function connectOnReturn(event: var): void {
                event.accepted = true;
                page.connect();
            }

            // Return is taken here: let through, it reached the settings dialog, which took it for OK
            // and closed before the connection had answered, and what it brought was not kept.
            Keys.onReturnPressed: event => passwordField.connectOnReturn(event)
            Keys.onEnterPressed: event => passwordField.connectOnReturn(event)
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, page.cfg_passwordHash !== "" ? "config.passwordKept" : "config.passwordHint")
        }

        QQC2.CheckBox {
            checked: page.cfg_rememberPassword
            text: I18n.t(page.language, "config.remember")

            onToggled: {
                page.cfg_rememberPassword = checked;

                // Not remembering means forgetting what was remembered.
                if (!checked) {
                    page.cfg_passwordHash = "";
                }
            }
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.rememberHint")
        }

        QQC2.TextField {
            Kirigami.FormData.label: I18n.t(page.language, "config.companyId")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            inputMethodHints: Qt.ImhDigitsOnly
            text: page.cfg_companyId

            onTextEdited: page.cfg_companyId = text.trim()
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: I18n.t(page.language, "config.companyHint")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Button {
            objectName: "connectButton"
            enabled: !page.busy
            icon.name: "network-connect"
            text: I18n.t(page.language, page.busy ? "config.connecting" : "config.connect")

            onClicked: page.connect()
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            wrapMode: Text.WordWrap
            color: page.connected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
            text: page.connected
                ? I18n.t(page.language, "config.connected", { date: new Date(page.cfg_tokenExpiresAt * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat) })
                : I18n.t(page.language, "config.notConnected")
        }

        QQC2.Label {
            Layout.maximumWidth: page.hintWidth
            visible: page.message !== ""
            wrapMode: Text.WordWrap
            color: page.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            text: page.message
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: I18n.t(page.language, "config.station")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            visible: page.stations.length > 0
            model: page.stations.map(station => station.name)
            currentIndex: page.stations.map(station => station.id).indexOf(page.cfg_stationId)

            onActivated: index => page.pick(page.stations[index])
        }

        QQC2.Label {
            Kirigami.FormData.label: I18n.t(page.language, "config.station")
            visible: page.stations.length === 0
            font.weight: page.cfg_stationName !== "" ? Font.DemiBold : Font.Normal
            text: page.cfg_stationName !== "" ? page.cfg_stationName : I18n.t(page.language, "config.stationNone")
        }
    }
}
