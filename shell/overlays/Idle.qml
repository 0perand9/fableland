import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// What happens when nobody touches the machine: the daemon stops counting
// focus time, the session locks, the screens go dark. Each stage has its own
// delay (minutes) in the settings; 0 switches that stage off.
Scope {
    // An idle monitor whose delay is a number of minutes.
    component After: IdleMonitor {
        required property real minutes

        enabled: minutes > 0
        timeout: minutes * 60
    }

    After {
        id: away

        function report() {
            Daemon.send("focus.setIdle", { idle: isIdle });
        }

        minutes: Daemon.has("focus") ? Daemon.setting("focus.idleMinutes", 5) : 0
        onIsIdleChanged: report()
    }

    // A daemon that (re)starts in the middle of a break has not heard about it.
    Connections {
        target: Daemon

        function onConnectedChanged() {
            if (Daemon.connected && away.isIdle)
                away.report();
        }
    }

    After {
        minutes: Daemon.has("lock") ? Daemon.setting("idle.lockMinutes", 0) : 0
        onIsIdleChanged: {
            if (isIdle)
                Daemon.send("session.lock");
        }
    }

    After {
        minutes: Daemon.setting("idle.screenOffMinutes", 0)
        // Dark after the delay, back on with the first key press or pointer movement.
        onIsIdleChanged: Daemon.send("session.screen", { on: !isIdle })
    }
}
