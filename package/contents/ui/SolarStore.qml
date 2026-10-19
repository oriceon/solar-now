import QtQuick

import "../code/deye.mjs" as Deye

/**
 * Loads the latest data of the station from Deye Cloud and keeps it fresh, asking for a new
 * token when the one on hand is missing, about to expire or refused.
 */
QtObject {
    id: store

    property string region: "eu"
    property string customUrl
    property string appId
    property string appSecret
    property string login
    /** SHA-256 of the password; empty when the user did not let the widget remember it. */
    property string passwordHash
    property string companyId
    property string accessToken
    /** Seconds since 1970. */
    property real tokenExpiresAt: 0
    property string stationId
    property int refreshMinutes: 5
    /** Whether the energy totals of the day are loaded too. */
    property bool totalsEnabled: true

    /** False until the settings hold an account the widget could ask a token for, or a token. */
    readonly property bool hasAccount: appId !== "" && appSecret !== "" && login !== "" && (accessToken !== "" || passwordHash !== "")
    readonly property bool configured: hasAccount && stationId !== ""

    /** parseLatest() of code/deye.mjs. It stays available while a refresh is running or failing. */
    property var latest: null
    /** parseDay() of code/deye.mjs for today, null while unknown. */
    property var day: null
    /** What the data on hand was asked for. */
    property string loadedKey: ""
    property date fetchedAt
    property bool loading: false
    /** Empty, or why the last refresh failed: login, credentials, rate, network, api or malformed. */
    property string problem: ""
    /** What the API said about it, in its own words, when it said anything. */
    property string problemText: ""
    property int failures: 0

    readonly property string requestKey: [region, customUrl, appId, stationId].join("|")
    /** False while the data on hand belongs to another account or station than the configured one. */
    readonly property bool ready: latest !== null && loadedKey === requestKey
    /** The user has to act before another attempt makes sense. */
    readonly property bool waitsForUser: problem === "login" || problem === "credentials"

    /** A request that has not answered by then is given up, and tried again like any other failure. */
    readonly property int patienceSeconds: 25
    /** The totals of the day change slowly; they are not asked for with every refresh. */
    readonly property int totalsMinutes: 10
    property int requestSerial: 0
    property string dayKey: ""
    property real dayLoadedAt: 0

    /** What waits for the token being asked for: `{ proceed, giveUp }` pairs; null while no token is asked for. */
    property var tokenWaiters: null
    /** When that token was asked for, in milliseconds since 1970. */
    property real tokenAskedAt: 0

    /** A token was issued; whoever owns the settings keeps it. */
    signal tokenIssued(string accessToken, real expiresAt)

    readonly property ApiClient client: ApiClient {}

    readonly property Timer refreshTimer: Timer {
        interval: (store.problem !== "" ? Deye.retryMinutes(store.failures) : store.refreshMinutes) * 60 * 1000
        repeat: true
        running: store.configured && !store.waitsForUser

        onTriggered: store.refresh()
    }

    // Started by every refresh and stopped by its answer: a refresh that replaces one still on its way gets the whole time.
    readonly property Timer patienceTimer: Timer {
        interval: store.patienceSeconds * 1000

        onTriggered: {
            store.fail(store.requestSerial, { kind: "network", message: "", detail: "the request timed out" });
            // Whatever the request still answers is ignored from here on.
            store.requestSerial++;
        }
    }

    function nowSeconds(): real {
        return Date.now() / 1000;
    }

    function fail(serial: int, response: var): void {
        if (serial !== requestSerial) {
            return;
        }

        loading = false;
        patienceTimer.stop();
        failures++;
        // A refused token that cannot be replaced is the user's to solve: the password is needed again.
        problem = response.kind === "token" ? "login" : response.kind;
        // Only the words of the API reach the screen; what the widget itself has to add is for the log.
        problemText = response.message || "";
        console.warn("Solar Now: the data could not be loaded:", problem, problemText || response.detail || "");
    }

    /** While the widget waits for the user, new credentials are worth another attempt right away. */
    function retryWithNewCredentials(): void {
        if (waitsForUser) {
            Qt.callLater(store.refresh);
        }
    }

    function refresh(): void {
        if (!configured) {
            return;
        }

        const serial = ++requestSerial;

        loading = true;
        patienceTimer.restart();

        if (mustRenewToken()) {
            renewToken(serial, token => store.loadLatest(serial, token, true));
        } else {
            loadLatest(serial, accessToken, false);
        }
    }

    /**
     * Asks for a new token with the remembered password and hands it to `proceed`; a refusal goes
     * to `giveUp` as a failed response.
     */
    function issueToken(proceed: var, giveUp: var): void {
        // The live data and the tabs may all find the token about to expire at once: they share one request.
        // One that has not answered within a minute is taken as lost, like any other.
        if (tokenWaiters !== null && Date.now() - tokenAskedAt < 60 * 1000) {
            tokenWaiters.push({ proceed: proceed, giveUp: giveUp });

            return;
        }

        const account = { region: region, customUrl: customUrl, appId: appId, appSecret: appSecret, login: login, passwordHash: passwordHash, companyId: companyId };

        tokenWaiters = [{ proceed: proceed, giveUp: giveUp }];
        tokenAskedAt = Date.now();

        client.post(Deye.tokenRequest(account), "", response => {
            const waiters = store.tokenWaiters || [];
            const token = response.ok ? Deye.parseToken(response.data, store.nowSeconds()) : null;

            store.tokenWaiters = null;

            if (token === null) {
                // A refused password is not a token to renew again.
                const failure = response.ok
                    ? { kind: "api", message: "", detail: "the token answer has no token" }
                    : { kind: response.kind === "token" ? "credentials" : response.kind, message: response.message };

                waiters.forEach(waiter => waiter.giveUp(failure));

                return;
            }

            store.tokenIssued(token.accessToken, token.expiresAt);
            waiters.forEach(waiter => waiter.proceed(token.accessToken));
        });
    }

    /** A token about to expire is renewed if it can be; one that cannot be renewed is used for as long as it lasts. */
    function mustRenewToken(): bool {
        const now = nowSeconds();

        return Deye.tokenNeedsRenewal(accessToken, tokenExpiresAt, now) && (passwordHash !== "" || accessToken === "" || tokenExpiresAt <= now);
    }

    function renewToken(serial: int, proceed: var): void {
        if (passwordHash === "") {
            fail(serial, { kind: "token", message: "" });

            return;
        }

        issueToken(token => {
            if (serial === store.requestSerial) {
                proceed(token);
            }
        }, response => store.fail(serial, response));
    }

    /**
     * For whoever else talks to the API: hands a token that is not about to expire to `receive`,
     * asking for a new one first when needed. `giveUp` is called when there is none to be had.
     */
    function withToken(receive: var, giveUp: var): void {
        if (!hasAccount) {
            giveUp();
        } else if (!mustRenewToken()) {
            receive(accessToken);
        } else if (passwordHash === "") {
            giveUp();
        } else {
            issueToken(receive, giveUp);
        }
    }

    /** `renewed` is true when the token was just issued, so a refusal is not answered by asking for yet another. */
    function loadLatest(serial: int, token: string, renewed: bool): void {
        const key = requestKey;

        client.post(Deye.stationLatestRequest(region, customUrl, stationId), token, response => {
            // A newer request makes this answer obsolete.
            if (serial !== store.requestSerial) {
                return;
            }

            if (!response.ok && response.kind === "token" && !renewed) {
                store.renewToken(serial, fresh => store.loadLatest(serial, fresh, true));

                return;
            }

            if (!response.ok) {
                store.fail(serial, response);

                return;
            }

            store.latest = Deye.parseLatest(response.data);
            store.loadedKey = key;
            store.fetchedAt = new Date();
            store.loading = false;
            store.patienceTimer.stop();
            store.failures = 0;
            store.problem = "";
            store.problemText = "";
            store.loadDay(serial, token);
        });
    }

    /** The totals are an extra: a failure leaves the old ones in place and is not reported. */
    function loadDay(serial: int, token: string): void {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        const key = `${requestKey}|${today}`;

        if (!totalsEnabled) {
            day = null;
            dayKey = "";

            return;
        }

        if (key === dayKey && Date.now() - dayLoadedAt < totalsMinutes * 60 * 1000) {
            return;
        }

        client.post(Deye.dayRequest(region, customUrl, stationId, today), token, response => {
            if (serial !== store.requestSerial || !response.ok) {
                return;
            }

            store.day = Deye.parseDay(response.data, today);
            store.dayKey = key;
            store.dayLoadedAt = Date.now();
        });
    }

    onConfiguredChanged: Qt.callLater(store.refresh)
    onRequestKeyChanged: {
        // The totals on hand belong to the station that was shown before.
        day = null;
        dayKey = "";
        Qt.callLater(store.refresh);
    }
    onAccessTokenChanged: retryWithNewCredentials()
    onPasswordHashChanged: retryWithNewCredentials()
    onTotalsEnabledChanged: Qt.callLater(store.refresh)
    Component.onCompleted: Qt.callLater(store.refresh)
}
