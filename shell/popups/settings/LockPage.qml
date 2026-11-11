import QtQuick
import qs.core

SettingsPage {
    Section {
        title: "Lock screen"
        feature: "lock"

        ToggleRow {
            id: hidePassword

            path: "lock.hidePassword"
            label: "Hide the password"
            hint: "Show only dots, never the character just typed"
        }

        NumberRow {
            path: "lock.revealMs"
            label: "Reveal characters for"
            hint: hidePassword.checked ? "Used once the password is not hidden" : "Then each one turns into a dot"
            keywords: "password show"
            from: 0
            to: 3000
            step: 100
            unit: "ms"
        }

        TextRow {
            path: "lock.pamConfig"
            label: "PAM service"
            hint: "Checks the password; “login” if empty"
            keywords: "authentication password"
            stacked: false
            placeholder: "login"
        }

        ActionRow {
            label: "Lock now"
            keywords: "lock screen session"
            button: "Lock"
            icon: Icons.lock
            onTriggered: Daemon.send("session.lock")
        }
    }

    Section {
        title: "When idle"

        NumberRow {
            path: "idle.lockMinutes"
            available: Daemon.has("lock")
            label: "Lock after"
            keywords: "automatic timeout"
            from: 0
            to: 240
            unit: "min"
            zeroLabel: "Never"
        }

        NumberRow {
            path: "idle.screenOffMinutes"
            label: "Screens off after"
            keywords: "automatic timeout dpms display sleep"
            from: 0
            to: 240
            unit: "min"
            zeroLabel: "Never"
        }
    }
}
