import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.widgets

// The top bar: floating groups for shortcuts, workspaces, media, the clock,
// the system tray and status.
PanelWindow {
    id: bar

    required property var modelData

    // The settings sidebar covers the left edge; the bar's left side moves out of its way.
    readonly property bool sidebarOpen: Ui.current === "settings" && Ui.screen === screen
    readonly property int updates: Daemon.updates.count

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barZone
    exclusiveZone: Theme.barZone
    color: "transparent"
    WlrLayershell.namespace: "fableland-bar"

    Item {
        anchors.fill: parent
        anchors.topMargin: Theme.barMargin
        anchors.leftMargin: Theme.px(4)
        anchors.rightMargin: Theme.px(4)

        // Where the clock sits when nothing is in its way.
        readonly property real middle: (width - center.width) / 2

        Row {
            id: left

            x: bar.sidebarOpen ? Theme.px(450) : 0
            spacing: Theme.px(4)

            Behavior on x {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }

            BarGroup {
                IconBtn {
                    visible: Daemon.setting("showHelpIcon", true)
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.help
                    iconColor: Theme.subtext
                    active: Ui.current === "guide"
                    onClicked: Ui.toggle("guide", "", bar.screen)
                }

                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.search
                    iconColor: Theme.accent
                    active: Ui.current === "launcher"
                    onClicked: Ui.toggle("launcher", "", bar.screen)
                }

                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.settings
                    iconColor: Theme.subtext
                    active: Ui.current === "settings"
                    onClicked: Ui.toggle("settings", "", bar.screen)
                }

                IconBtn {
                    id: updateButton

                    visible: bar.updates > 0 || Ui.current === "updates"
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.update
                    iconColor: Theme.green
                    accentColor: Theme.green
                    active: Ui.current === "updates"
                    onClicked: Ui.toggle("updates", "", bar.screen)

                    // Breathes while updates are waiting.
                    SequentialAnimation on opacity {
                        running: updateButton.visible && !updateButton.active
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation { to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
            }

            Workspaces {
                order: 1
                screen: bar.screen
            }

            Media {
                order: 2
                screen: bar.screen
                // Beside the sidebar there is no room for it.
                visible: shown && !bar.sidebarOpen
                // Never run into the clock.
                maxTitleWidth: Math.max(Theme.px(60), Math.min(Theme.px(240), parent.parent.middle - x - Theme.px(190)))
            }
        }

        Clock {
            id: center

            // In the middle, unless the left side — pushed over by the sidebar — needs the room.
            x: Math.max(parent.middle, left.x + left.width + Theme.px(4))
            order: 3
            screen: bar.screen
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.px(4)

            // What plugins put in the bar.
            Slot {
                name: "bar"
                spacing: Theme.px(4)
                context: ({ screen: bar.screen })
            }

            Tray {
                order: 5
                window: bar
            }

            Status {
                order: 4
                screen: bar.screen
            }
        }
    }
}
