import QtQuick
import qs.core

SettingsPage {
    Section {
        title: "Interface"

        NumberRow {
            path: "uiScale"
            label: "UI scale"
            hint: "Scales the whole interface"
            keywords: "size zoom dpi"
            factor: 0.01
            from: 50
            to: 250
            step: 5
            unit: "%"
        }

        NumberRow {
            path: "workspaceCount"
            label: "Workspaces"
            hint: "Pills shown in the bar"
            from: 1
            to: 20
        }

        ToggleRow {
            path: "showHelpIcon"
            label: "Help icon"
            hint: "The guide's button in the bar"
        }

        ToggleRow {
            path: "openGuideAtStartup"
            label: "Guide at startup"
            hint: "Open the guide when the session starts"
        }
    }

    Section {
        title: "Behaviour"

        TextRow {
            path: "terminal"
            label: "Terminal"
            hint: "For terminal apps and updates"
            stacked: false
            placeholder: "kitty"
        }

        TextRow {
            path: "launcher.searchUrl"
            label: "Web search"
            hint: "The link the launcher's ? search opens. {query} is filled in."
            keywords: "launcher search engine url link browser"
            icon: Icons.web
        }

        ToggleRow {
            path: "osd"
            label: "On-screen display"
            hint: "Show volume and brightness changes"
            keywords: "osd popup"
        }

        ToggleRow {
            path: "sounds"
            label: "Sounds"
            hint: "Play the shell's sound effects"
            keywords: "audio effects"
        }
    }
}
