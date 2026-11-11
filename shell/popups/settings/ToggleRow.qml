import QtQuick
import qs.core
import qs.widgets

// An on/off setting. Clicking anywhere on the row flips it.
SettingRow {
    id: root

    readonly property bool checked: Daemon.setting(path, false) === true

    clickable: true
    onClicked: Daemon.setSetting(path, !checked)
    // Left is off, Right is on.
    onNudged: by => {
        if (by > 0 !== checked)
            clicked();
    }

    Toggle {
        checked: root.checked
        onToggled: root.clicked()
    }
}
