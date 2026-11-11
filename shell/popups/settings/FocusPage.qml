import QtQuick
import qs.core

SettingsPage {
    Section {
        title: "Screen time"

        NumberRow {
            path: "focus.idleMinutes"
            label: "Away after"
            hint: "Time without input after which nothing is counted"
            keywords: "idle afk"
            from: 1
            to: 120
            unit: "min"
        }

        ToggleRow {
            path: "focus.countSystem"
            label: "Count the desktop itself"
            hint: "Include the shell and other system surfaces in the statistics"
            keywords: "system shell"
        }

        ActionRow {
            label: "Screen time"
            hint: "Today, the week and the month per application"
            keywords: "focus statistics"
            button: "Open"
            icon: Icons.chart
            onTriggered: Ui.open("focus")
        }
    }
}
