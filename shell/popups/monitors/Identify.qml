import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.widgets

// Writes its name on every monitor while `active`, so that monitors of the
// same make can be told apart before they are arranged.
Variants {
    id: root

    property bool active: false

    model: active ? Quickshell.screens : []

    PanelWindow {
        id: badge

        required property var modelData
        // What the daemon knows about this screen (its mode, rather than its size after scaling).
        readonly property var monitor: Daemon.monitors.find(m => m.name === modelData.name) ?? null

        screen: modelData
        // In a corner, clear of the popup in the middle of the screen.
        anchors {
            left: true
            bottom: true
        }
        margins.left: Theme.px(40)
        margins.bottom: Theme.px(40)
        implicitWidth: Theme.px(340)
        implicitHeight: Theme.px(170)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fableland-identify"
        // Only a label: the pointer goes through it.
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: Theme.alpha(Theme.base, 0.92)
            border.width: Theme.px(2)
            border.color: Theme.accent

            NumberAnimation on scale {
                from: 0.8
                to: 1
                duration: Theme.slow
                easing.type: Easing.OutBack
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(4)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.monitor
                    size: 34
                    color: Theme.accent
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: badge.modelData.name
                    size: 34
                    bold: true
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: badge.monitor ? badge.monitor.model + " · " + badge.monitor.width + " × " + badge.monitor.height : badge.modelData.model
                    size: 13
                    color: Theme.subtext
                }
            }
        }
    }
}
