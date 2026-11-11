import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.overlays.lock

// The session lock. It goes up when the daemon reports the session as locked
// and comes down for one reason only: a password that PAM accepts. A daemon
// that restarts, disconnects or changes its mind does not open it — and a
// daemon that is gone cannot keep it shut either.
Scope {
    id: root

    // Whether the lock is up: set by the daemon's `session.locked`, cleared by a password alone.
    property bool locked: false
    // Unlocked here, but the daemon has not confirmed it yet (it may be unreachable).
    property bool unlockPending: false

    // Bring this lock and the daemon's idea of the session back in line.
    function follow() {
        if (!Daemon.session.locked) {
            unlockPending = false;
            // A restarted daemon has forgotten the lock. It stands; remind the daemon.
            if (locked)
                Daemon.send("session.lock");
        } else if (unlockPending) {
            // The daemon missed the unlock while it could not be reached.
            Daemon.send("session.unlock");
        } else {
            locked = true;
        }
    }

    onLockedChanged: {
        if (locked)
            authenticator.reset();
        sessionLock.locked = locked;
    }
    Component.onCompleted: follow()

    Connections {
        target: Daemon

        function onSessionChanged() {
            root.follow();
        }
    }

    // The rest of the shell asks Ui whether the session is locked.
    Binding {
        target: Ui
        property: "lockHeld"
        value: root.locked
    }

    // Quickshell (0.3) dies with a protocol error when its files are hot-reloaded
    // under a session lock, so edits to the shell wait until the lock is down.
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: false
        when: root.locked
    }

    Auth {
        id: authenticator

        onSucceeded: {
            root.unlockPending = Daemon.session.locked;
            root.locked = false;
            Daemon.send("session.unlock");
        }
    }

    WlSessionLock {
        id: sessionLock

        // `secure` reports the compositor's verdict. `locked` does not: after a
        // refusal it is silently off again.
        onSecureStateChanged: retry.running = root.locked && !secure

        WlSessionLockSurface {
            color: Theme.base

            LockScreen {
                anchors.fill: parent
                auth: authenticator
            }
        }
    }

    // The compositor refuses the lock while another locker holds one (or a
    // restarted shell may not yet take over the lock its predecessor left
    // behind). The session is meant to be locked, so keep asking.
    Timer {
        id: retry

        interval: 1000
        repeat: true
        onTriggered: sessionLock.locked = true
    }

    // Development preview (FABLE_DEV_OPEN=lock): the lock screen in an ordinary
    // window that locks nothing.
    LazyLoader {
        active: Ui.dev === "lock"

        PanelWindow {
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.base
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "fableland-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockScreen {
                anchors.fill: parent
                auth: authenticator
            }
        }
    }
}
