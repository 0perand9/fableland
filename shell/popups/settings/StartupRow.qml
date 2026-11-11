import QtQuick
import qs.core
import qs.widgets

// One startup command: whether it runs, the command itself, and its place in the order.
EntryCard {
    id: root

    readonly property bool active: entry?.enabled !== false

    implicitHeight: Theme.px(52)
    onActivated: {
        command.forceActiveFocus();
        command.input.selectAll();
    }

    Toggle {
        id: toggle

        x: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        checked: root.active
        onToggled: checked => root.editor.update(root.index, { enabled: checked })
    }

    CommitField {
        id: command

        anchors.left: toggle.right
        anchors.right: buttons.left
        anchors.leftMargin: Theme.px(10)
        anchors.rightMargin: Theme.px(4)
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.active ? 1 : 0.5
        value: root.entry?.command ?? ""
        placeholder: "Command"
        // An emptied command has nothing left to start.
        onCommitted: text => text.trim() === "" ? root.editor.remove(root.index) : root.editor.update(root.index, { command: text.trim() })
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
