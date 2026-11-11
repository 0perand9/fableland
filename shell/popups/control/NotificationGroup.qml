import QtQuick
import qs.core
import qs.widgets

// The line above an application's notifications: click to fold them away,
// or dismiss them all at once.
Item {
    id: root

    // { app, count, icon, folded } (see NotificationCenter.entries).
    property var entry: ({})

    signal foldToggled

    implicitHeight: Theme.px(34)

    Clickable {
        id: fold

        anchors.left: parent.left
        anchors.right: dismiss.left
        anchors.rightMargin: Theme.px(4)
        anchors.bottom: parent.bottom
        height: Theme.px(28)
        onClicked: root.foldToggled()

        Row {
            x: Theme.px(6)
            width: parent.width - 2 * x
            height: parent.height
            spacing: Theme.px(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.chevronDown
                size: 15
                color: Theme.dim
                rotation: root.entry.folded ? -90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                }
            }

            AppIcon {
                id: appIcon

                anchors.verticalCenter: parent.verticalCenter
                icon: root.entry.icon ?? ""
                glyph: Icons.bell
                size: 16
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - x - count.width - parent.spacing)
                text: (root.entry.app ?? "").toUpperCase()
                size: 11
                bold: true
                color: Theme.subtext
                font.letterSpacing: Theme.px(0.8)
            }

            Txt {
                id: count

                anchors.verticalCenter: parent.verticalCenter
                text: root.entry.count ?? ""
                size: 11
                color: Theme.dim
            }
        }
    }

    IconBtn {
        id: dismiss

        anchors.right: parent.right
        anchors.verticalCenter: fold.verticalCenter
        icon: Icons.close
        size: 24
        iconColor: hovered ? Theme.red : Theme.dim
        onClicked: Daemon.send("notif.dismissApp", { app: root.entry.app })
    }
}
