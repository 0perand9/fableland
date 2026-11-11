import QtQuick
import qs.core
import qs.widgets

// One keybind in the list: a summary that opens into its form when clicked.
EntryCard {
    id: root

    // The fable vocabulary, for the form.
    property var commands: []
    // (keys, index) → what else uses that combination, "" when it is free.
    property var conflictOf: (keys, index) => ""

    readonly property var bind: entry ?? ({})
    readonly property bool open: editor.expanded === index
    readonly property bool active: bind.enabled !== false
    readonly property string keys: bind.keys ?? ""
    readonly property string command: bind.command ?? ""
    readonly property string conflict: keys !== "" && active ? conflictOf(keys, index) : ""
    // The daemon skips a keybind without keys or without a command.
    readonly property string missing: keys === "" ? "No keys yet" : command === "" ? "Nothing to run yet" : ""
    // Animating the height only after creation keeps rows from growing in while the list scrolls.
    property bool settled: false

    function toggleOpen() {
        editor.expanded = open ? -1 : index;
    }

    implicitHeight: summary.height + (open ? form.height : 0)
    clip: true
    color: Theme.alpha(Theme.surface0, open || hover.containsMouse ? 0.8 : 0.55)
    border.color: activeFocus ? Theme.alpha(Theme.accent, 0.6) : open ? Theme.alpha(Theme.accent, 0.35) : Theme.border

    onActivated: toggleOpen()
    Component.onCompleted: {
        settled = true;
        // Created already open (it was just added): its form may reach below the list's edge.
        if (open)
            Qt.callLater(reveal);
    }

    Behavior on implicitHeight {
        enabled: root.settled

        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && root.open)
                    root.reveal();
            }
        }
    }
    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }

    Item {
        id: summary

        width: parent.width
        height: Theme.px(62)

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleOpen()
        }

        Column {
            x: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * x - trailing.width - Theme.px(10)
            spacing: Theme.px(6)
            opacity: root.active ? 1 : 0.45

            Row {
                visible: root.keys !== ""
                height: Theme.px(22)
                spacing: Theme.px(8)

                KeyCaps {
                    keys: root.keys
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.conflict !== ""
                    text: Icons.warning
                    size: 14
                    color: Theme.yellow
                }
            }

            Txt {
                width: parent.width
                text: root.missing !== "" ? root.missing : root.bind.description ? root.bind.description : root.command
                size: 12
                color: root.missing !== "" ? Theme.yellow : Theme.subtext
            }
        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: Theme.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(6)

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.active
                onToggled: checked => root.editor.update(root.index, { enabled: checked })
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.chevronDown
                size: 18
                color: Theme.dim
                rotation: root.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Loader {
        id: form

        anchors.top: summary.bottom
        width: parent.width
        active: root.open
        sourceComponent: KeybindForm {
            editor: root.editor
            index: root.index
            commands: root.commands
            conflict: root.conflict
        }
    }
}
