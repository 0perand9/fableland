import QtQuick
import qs.core
import qs.widgets

// Lock, sleep, log out, restart and power off. What ends the session must be
// held until its tile has filled; locking and sleeping act on a click.
Column {
    id: root

    // Locking is a feature; the other four are always there.
    readonly property bool canLock: Daemon.has("lock")
    readonly property int count: canLock ? 5 : 4
    readonly property real tileWidth: (width - (count - 1) * tiles.spacing) / count
    readonly property real tileHeight: Theme.px(74)

    spacing: Theme.px(8)

    // A click tile that looks like its HoldBtn neighbours.
    component Tile: Clickable {
        id: tile

        property string icon: ""
        property string text: ""
        property color hue: Theme.accent

        width: root.tileWidth
        height: root.tileHeight
        fill: Theme.alpha(Theme.surface1, 0.6)
        border.width: 1
        border.color: Theme.alpha(hue, hovered ? 0.5 : 0.15)

        Column {
            anchors.centerIn: parent
            spacing: Theme.px(8)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.icon
                size: 22
                color: label.color
            }

            Txt {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.text
                size: 11
                bold: true
                color: tile.hovered ? tile.hue : Theme.text

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }
            }
        }
    }

    component HoldTile: HoldBtn {
        width: root.tileWidth
        height: root.tileHeight
        vertical: true
        size: 11
        iconSize: 22
    }

    Row {
        id: tiles

        spacing: Theme.px(8)

        Tile {
            visible: root.canLock
            icon: Icons.lock
            text: "Lock"
            onClicked: Daemon.send("session.lock")
        }

        Tile {
            icon: Icons.sleep
            text: "Sleep"
            onClicked: Daemon.send("session.suspend")
        }

        HoldTile {
            icon: Icons.logout
            text: "Log out"
            accentColor: Theme.yellow
            onTriggered: Daemon.send("session.logout")
        }

        HoldTile {
            icon: Icons.restart
            text: "Restart"
            accentColor: Theme.yellow
            onTriggered: Daemon.send("session.reboot")
        }

        HoldTile {
            icon: Icons.power
            text: "Power off"
            accentColor: Theme.red
            onTriggered: Daemon.send("session.poweroff")
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Hold to log out, restart or power off"
        size: 10
        color: Theme.dim
    }
}
