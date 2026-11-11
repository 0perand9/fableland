import QtQuick
import qs.core
import qs.widgets

// The buttons at the end of a ListEditor entry: move it up or down, remove it.
Row {
    id: root

    required property ListEditor editor
    required property int index

    spacing: Theme.px(2)

    // Up and down share the width of one button, leaving the entry's text more room.
    Column {
        anchors.verticalCenter: parent.verticalCenter

        IconBtn {
            icon: Icons.chevronUp
            size: 22
            iconSize: 16
            iconColor: Theme.subtext
            interactive: root.index > 0
            onClicked: root.editor.move(root.index, -1)
        }

        IconBtn {
            icon: Icons.chevronDown
            size: 22
            iconSize: 16
            iconColor: Theme.subtext
            interactive: root.index < root.editor.entries.length - 1
            onClicked: root.editor.move(root.index, 1)
        }
    }

    IconBtn {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.trash
        size: 28
        iconColor: Theme.red
        onClicked: root.editor.remove(root.index)
    }
}
