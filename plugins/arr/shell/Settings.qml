import QtQuick
import qs.core
import qs.popups.settings
import qs.plugins.arr

SettingsPage {
    Section {
        ToggleRow {
            path: "arr.search"
            label: "Search right away"
            hint: "A requested title is searched for as soon as it is added, rather than at the next scheduled search."
            keywords: "download arr sonarr radarr"
        }
    }

    Server {
        service: "sonarr"
        port: "8989"
    }

    Server {
        service: "radarr"
        port: "7878"
    }
}
