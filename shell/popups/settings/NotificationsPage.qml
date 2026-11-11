import QtQuick
import qs.core

SettingsPage {
    Section {
        ToggleRow {
            path: "notifications.dnd"
            label: "Do not disturb"
            hint: "Collect notifications silently; critical ones still pop up"
            keywords: "dnd silence mute"
        }

        NumberRow {
            path: "notifications.timeoutMs"
            label: "Stay on screen"
            hint: "Unless a notification asks otherwise"
            keywords: "timeout duration seconds"
            factor: 1000
            from: 1
            to: 60
            decimals: 1
            unit: "s"
        }

        ActionRow {
            label: "Test notification"
            hint: "Send one to see how it looks"
            keywords: "notifications try"
            button: "Send"
            icon: Icons.bellRing
            onTriggered: Daemon.send("notif.test")
        }
    }
}
