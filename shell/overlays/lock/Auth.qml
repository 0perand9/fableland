import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.core

// Password authentication for the lock screen. One instance is shared by the
// lock surfaces of all screens, so what is typed on one shows on every one.
Scope {
    id: root

    // What has been typed so far.
    property string password: ""
    readonly property bool checking: pam.active
    // Why the last attempt did not unlock; "" when there is nothing to report.
    property string failure: ""
    // Something a PAM module wants the user to know while it works (e.g. a fingerprint reader).
    property string notice: ""

    // The PAM service to authenticate against: the `lock.pamConfig` setting, or
    // "login", which every system has and which the old lock screen used too.
    readonly property string fallbackConfig: "login"
    readonly property string wantedConfig: Daemon.setting("lock.pamConfig", "") || fallbackConfig
    // Set when the wanted service turned out not to exist; a typo in the
    // settings must not lock the user out.
    property bool wantedConfigBroken: false

    signal succeeded
    signal rejected

    function submit() {
        if (password === "" || checking)
            return;
        failure = "";
        notice = "";
        if (pam.start())
            return;
        if (pam.config !== fallbackConfig) {
            wantedConfigBroken = true;
            if (pam.start())
                return;
        }
        fail("Cannot check passwords");
    }

    // Forget what was typed and what went wrong.
    function reset() {
        password = "";
        failure = "";
    }

    function fail(reason) {
        password = "";
        failure = reason;
        rejected();
    }

    onWantedConfigChanged: wantedConfigBroken = false
    // A new attempt has begun: the old verdict is history.
    onPasswordChanged: {
        if (password !== "")
            failure = "";
    }

    PamContext {
        id: pam

        config: root.wantedConfigBroken ? root.fallbackConfig : root.wantedConfig
        onPamMessage: {
            // Every prompt is for the password: there is nothing else to answer with.
            if (responseRequired)
                respond(root.password);
            else
                root.notice = message;
        }
        onCompleted: result => {
            root.notice = "";
            if (result === PamResult.Success) {
                root.password = "";
                root.succeeded();
            } else {
                root.fail(result === PamResult.MaxTries ? "Too many attempts" : result === PamResult.Error ? "Cannot check passwords" : "Wrong password");
            }
        }
    }
}
