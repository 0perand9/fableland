import QtQuick
import qs.core
import qs.widgets

// One of the keyboard layouts in use, with its place in the order (the first is the default).
EntryCard {
    id: root

    // xkb layout id → its name in words.
    property var names: ({})
    readonly property string layout: entry ?? ""

    implicitHeight: Theme.px(52)

    Rectangle {
        id: badge

        x: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(26)
        height: Theme.px(26)
        radius: Theme.px(8)
        color: root.index === 0 ? Theme.accent : Theme.alpha(Theme.surface2, 0.6)

        Txt {
            anchors.centerIn: parent
            text: root.index + 1
            size: 12
            bold: true
            color: root.index === 0 ? Theme.accentText : Theme.subtext
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: buttons.left
        anchors.leftMargin: Theme.px(10)
        anchors.rightMargin: Theme.px(6)
        anchors.verticalCenter: parent.verticalCenter

        Txt {
            width: parent.width
            text: root.names[root.layout] ?? root.layout
            size: 13
        }

        Txt {
            width: parent.width
            text: root.index === 0 ? root.layout + " · default" : root.layout
            size: 11
            color: Theme.dim
        }
    }

    EntryButtons {
        id: buttons

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        editor: root.editor
        index: root.index
    }
}
