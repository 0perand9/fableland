import QtQuick
import qs.core

SettingsPage {
    id: page

    readonly property var info: Daemon.sysinfo
    readonly property string words: "about system information"

    Section {
        InfoRow { label: "Fableland"; value: page.info.version ?? ""; keywords: page.words + " version" }
        InfoRow { label: "System"; value: page.info.os ?? ""; keywords: page.words + " os distribution" }
        InfoRow { label: "Kernel"; value: page.info.kernel ?? ""; keywords: page.words }
        InfoRow { label: "Compositor"; value: page.info.compositor ?? ""; keywords: page.words + " hyprland" }
        InfoRow { label: "Host"; value: (page.info.user ?? "") + "@" + (page.info.host ?? ""); keywords: page.words + " user" }
        InfoRow { label: "CPU"; value: page.info.cpu ?? ""; keywords: page.words + " processor" }
        InfoRow { label: "GPU"; value: page.info.gpu ?? ""; keywords: page.words + " graphics" }
    }

    Section {
        title: "Maintenance"

        ActionRow {
            label: "Guide"
            hint: "What the shell can do, and its keys"
            keywords: "help"
            button: "Open"
            icon: Icons.help
            onTriggered: Ui.open("guide")
        }

        ActionRow {
            label: "Reload the shell"
            hint: "Restart the interface; the daemon keeps running"
            keywords: "restart"
            button: "Reload"
            icon: Icons.restart
            onTriggered: Daemon.send("ui.reload")
        }

        ActionRow {
            label: "Reset all settings"
            hint: "Back to the defaults — keybinds, startup commands and the saved monitor layout included"
            keywords: "defaults factory"
            button: "Hold to reset"
            destructive: true
            onTriggered: Daemon.send("settings.reset")
        }
    }
}
