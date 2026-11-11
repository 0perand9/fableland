import QtQuick
import qs.core
import qs.widgets

// The power button in the corner of the lock screen and the menu it opens.
// Sleeping is a click; restarting and powering off have to be held, because
// anybody walking past can reach them.
Item {
    id: root

    property bool open: false

    implicitWidth: button.width
    implicitHeight: button.height

    Rectangle {
        id: menu

        anchors.right: parent.right
        anchors.bottom: button.top
        anchors.bottomMargin: Theme.px(14)
        width: Theme.px(220)
        height: root.open ? actions.implicitHeight + 2 * Theme.pad : 0
        visible: height > 0
        radius: Theme.radius
        color: Theme.alpha(Theme.base, 0.9)
        border.width: 1
        border.color: Theme.border
        opacity: root.open ? 1 : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }

        // Clicks on the menu are not clicks on the lock screen behind it.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: actions

            x: Theme.pad
            y: Theme.pad
            width: parent.width - 2 * Theme.pad
            spacing: Theme.gap

            Btn {
                width: parent.width
                text: "Suspend"
                icon: Icons.sleep
                onClicked: {
                    root.open = false;
                    Daemon.send("session.suspend");
                }
            }

            HoldBtn {
                width: parent.width
                text: "Restart"
                icon: Icons.restart
                accentColor: Theme.yellow
                onTriggered: Daemon.send("session.reboot")
            }

            HoldBtn {
                width: parent.width
                text: "Power off"
                icon: Icons.power
                onTriggered: Daemon.send("session.poweroff")
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hold to restart or power off"
                size: 10
                color: Theme.dim
            }
        }
    }

    Clickable {
        id: button

        width: Theme.px(52)
        height: width
        radius: width / 2
        fill: root.open ? Theme.surface2 : Theme.alpha(Theme.surface0, 0.4)
        border.width: 1
        border.color: root.open ? Theme.alpha(Theme.text, 0.5) : Theme.alpha(Theme.text, 0.15)
        onClicked: root.open = !root.open

        Icon {
            anchors.centerIn: parent
            text: Icons.power
            size: 22
            color: root.open ? Theme.red : button.hovered ? Theme.text : Theme.subtext

            Behavior on color {
                ColorAnimation { duration: Theme.normal }
            }
        }
    }
}
