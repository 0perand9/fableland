import QtQuick
import qs.core
import qs.widgets

// One pill per media player, with the highlight on the active one. Clicking a
// pill makes that player the one the popup and the bar show and control.
Rectangle {
    id: root

    readonly property var media: Daemon.media
    readonly property real inset: Theme.px(4)
    readonly property real pillWidth: players.count > 0 ? (width - 2 * inset) / players.count : 0
    readonly property int activeIndex: media.players.findIndex(player => player.id === media.id)

    function statusGlyph(status) {
        return status === "Playing" ? Icons.play : status === "Paused" ? Icons.pause : Icons.stop;
    }

    implicitHeight: Theme.px(48)
    radius: height / 2
    color: Theme.alpha(Theme.surface0, 0.6)

    KeyedModel {
        id: players

        source: root.media.players
    }

    Stretch {
        y: root.inset
        height: root.height - 2 * root.inset
        targetStart: root.inset + root.activeIndex * root.pillWidth
        targetEnd: targetStart + root.pillWidth
        visible: root.activeIndex >= 0
    }

    Repeater {
        model: players.rows

        Item {
            id: pill

            required property string key
            required property int index
            readonly property var player: players.byKey[key] ?? ({})
            readonly property bool isActive: key === root.media.id

            x: root.inset + index * root.pillWidth
            y: root.inset
            width: root.pillWidth
            height: root.height - 2 * root.inset

            // The player's application icon, or its status when it has none.
            AppIcon {
                id: status

                x: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter
                icon: pill.player.icon ?? ""
                glyph: root.statusGlyph(pill.player.status)
                glyphColor: name.color
                size: 22
            }

            Column {
                anchors.left: status.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter

                Txt {
                    id: name

                    width: parent.width
                    text: pill.player.name ?? ""
                    size: 12
                    bold: true
                    color: pill.isActive ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }

                Txt {
                    width: parent.width
                    visible: text !== ""
                    text: pill.player.title ?? ""
                    size: 10
                    color: name.color
                    opacity: 0.8
                }
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Daemon.send("media.select", { id: pill.key })
            }
        }
    }
}
