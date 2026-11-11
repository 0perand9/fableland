import QtQuick
import qs.core
import qs.widgets

// Says that a setting is fixed by the system configuration (managed.json, see
// Daemon.fixed): it shows its value here but is changed there.
Row {
    spacing: Theme.px(5)

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.lock
        size: 11
        color: Theme.dim
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: "Set by the system configuration"
        size: 11
        color: Theme.dim
    }
}
