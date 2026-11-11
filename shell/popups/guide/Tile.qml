import QtQuick
import qs.core
import qs.widgets

// A card with a glyph, a name and a line or two about it. Clickable when it
// leads somewhere (`interactive`), with `trailing` hinting where.
Clickable {
    id: root

    property string icon: ""
    property color hue: Theme.accent
    property string title: ""
    property string text: ""
    property string trailing: ""

    implicitHeight: Theme.px(76)
    radius: Theme.radius
    fill: Theme.alpha(Theme.surface0, 0.55)
    border.width: 1
    border.color: hovered ? Theme.alpha(hue, 0.55) : Theme.border

    Behavior on border.color {
        ColorAnimation { duration: Theme.fast }
    }

    Rectangle {
        id: badge

        x: Theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(40)
        height: Theme.px(40)
        radius: Theme.radiusSmall
        color: Theme.alpha(root.hue, 0.16)

        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 21
            color: root.hue
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: hint.visible ? hint.left : parent.right
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(2)

        Txt {
            width: parent.width
            text: root.title
            size: 13
            bold: true
        }

        Txt {
            width: parent.width
            text: root.text
            size: 11
            color: Theme.subtext
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }

    Icon {
        id: hint

        visible: root.trailing !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        text: root.trailing
        size: 16
        color: root.hovered ? root.hue : Theme.dim
    }
}
