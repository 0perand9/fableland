import QtQuick
import qs.core
import qs.widgets

// One stop of the tour: a part of the shell, what it does, the command that
// brings it up and — where there is something to show — a button to try it.
Card {
    id: root

    property string icon: ""
    property string title: ""
    property string text: ""
    // The `fable` command for this part, "" when it has none.
    property string command: ""
    // The label of the try-it button, "" for parts that cannot be shown on demand.
    property string action: ""
    // Under the keyboard cursor.
    property bool selected: false

    signal tried

    implicitHeight: Theme.px(124)
    color: Theme.alpha(Theme.surface0, hover.hovered || selected ? 0.8 : 0.55)
    border.color: selected ? Theme.accent : hover.hovered ? Theme.alpha(Theme.accent, 0.35) : Theme.border

    Behavior on border.color {
        ColorAnimation { duration: Theme.fast }
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: badge

        x: Theme.px(14)
        y: Theme.px(14)
        width: Theme.px(36)
        height: Theme.px(36)
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.accent, 0.16)

        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 20
            color: Theme.accent
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: button.visible ? button.left : parent.right
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: Theme.px(10)
        anchors.verticalCenter: badge.verticalCenter

        Txt {
            width: parent.width
            text: root.title
            size: 13
            bold: true
        }

        Txt {
            visible: root.command !== ""
            width: parent.width
            text: root.command
            size: 10
            color: Theme.dim
        }
    }

    Btn {
        id: button

        visible: root.action !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: badge.verticalCenter
        height: Theme.px(28)
        text: root.action
        size: 11
        kind: root.selected ? "filled" : "tonal"
        onClicked: root.tried()
    }

    Txt {
        anchors.top: badge.bottom
        anchors.topMargin: Theme.px(10)
        x: badge.x
        width: parent.width - 2 * x
        text: root.text
        size: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        lineHeight: 1.15
    }
}
