import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    id: page

    readonly property int saved: Daemon.setting("monitors", []).length
    readonly property string words: "monitors displays screens"

    KeyedModel {
        id: connected

        source: Daemon.monitors
        key: "name"
    }

    Section {
        title: "Connected"

        Repeater {
            model: connected.rows

            InfoRow {
                required property string key
                readonly property var monitor: connected.byKey[key] ?? ({})

                label: key
                hint: monitor.model ?? ""
                keywords: page.words
                value: monitor.width + "×" + monitor.height + " · " + Math.round(monitor.refreshRate ?? 0) + " Hz · ×" + monitor.scale
            }
        }
    }

    Section {
        title: "Layout"

        ActionRow {
            label: "Arrange the displays"
            hint: "Mode, position, scale, rotation"
            keywords: page.words + " editor"
            button: "Open editor"
            icon: Icons.monitors
            onTriggered: Ui.open("monitors")
        }

        ActionRow {
            path: "monitors"
            label: "Saved layout"
            hint: "For " + page.saved + (page.saved === 1 ? " display" : " displays") + ", restored at every start"
            keywords: page.words + " forget"
            available: page.saved > 0
            button: "Hold to forget"
            destructive: true
            onTriggered: Daemon.setSetting("monitors", [])
        }
    }
}
