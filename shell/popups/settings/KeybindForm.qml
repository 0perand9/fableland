import QtQuick
import qs.core
import qs.widgets

// The form of one keybind, shown while its row is open. Each field is written
// as soon as it is committed, like every other setting.
Column {
    id: root

    required property ListEditor editor
    required property int index
    // The fable vocabulary: [{ command, about }].
    property var commands: []
    // What else uses this entry's combination; "" when it is free.
    property string conflict: ""

    readonly property var bind: editor.entries[index] ?? ({})
    readonly property var actions: [
        { value: "exec", label: "Program", placeholder: "A command line, like kitty" },
        { value: "fable", label: "Fable", placeholder: "Something from the list below" },
        { value: "lua", label: "Lua", placeholder: "hl.dsp.window.close()" }
    ]
    readonly property int action: Math.max(0, actions.findIndex(entry => entry.value === bind.action))
    readonly property bool fable: actions[action].value === "fable"
    readonly property var suggestions: {
        const typed = command.text.trim().toLowerCase();
        return commands.filter(entry => entry.command.includes(typed) || entry.about.toLowerCase().includes(typed));
    }

    function set(changes) {
        editor.update(index, changes);
    }

    // Take a suggestion. (Not done in the suggestion's own click handler: changing
    // the text rebuilds the list and with it the suggestion that was clicked.)
    function run(text) {
        command.text = text;
        command.edited = true;
        command.commit();
    }

    component Line: SettingRow {
        searchable: false
        padding: Theme.px(8)
    }

    component Flag: Line {
        id: flag

        property bool checked: false

        clickable: true

        Toggle {
            checked: flag.checked
            onToggled: flag.clicked()
        }
    }

    Line {
        label: "Keys"
        stacked: true
        onActivated: capture.record()

        Column {
            spacing: Theme.px(6)

            KeyCapture {
                id: capture

                width: parent.width
                keys: root.bind.keys ?? ""
                onCaptured: keys => root.set({ keys: keys })
            }

            Txt {
                visible: root.conflict !== ""
                width: parent.width
                text: root.conflict
                size: 11
                color: Theme.yellow
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }

    Line {
        label: "Runs"
        stacked: true
        onNudged: by => root.set({ action: root.actions[Math.max(0, Math.min(root.actions.length - 1, root.action + by))].value })
        onActivated: command.forceActiveFocus()

        Column {
            spacing: Theme.px(6)

            Tabs {
                width: parent.width
                implicitHeight: Theme.px(32)
                size: 12
                model: root.actions.map(entry => entry.label)
                current: root.action
                onSelected: index => root.set({ action: root.actions[index].value })
            }

            CommitField {
                id: command

                width: parent.width
                value: root.bind.command ?? ""
                placeholder: root.actions[root.action].placeholder
                icon: Icons.terminal
                onCommitted: text => root.set({ command: text.trim() })
            }

            List {
                id: vocabulary

                width: parent.width
                height: Math.min(contentHeight, Theme.px(112))
                visible: root.fable && command.activeFocus && count > 0
                spacing: 0
                model: root.suggestions

                delegate: Clickable {
                    id: suggestion

                    required property var modelData

                    width: vocabulary.width
                    height: Theme.px(28)
                    onClicked: root.run(modelData.command)

                    Txt {
                        id: words

                        x: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: suggestion.modelData.command
                        size: 12
                    }

                    Txt {
                        anchors.left: words.right
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: suggestion.modelData.about
                        size: 11
                        color: Theme.dim
                    }
                }
            }
        }
    }

    Line {
        label: "Description"
        stacked: true
        onActivated: description.forceActiveFocus()

        CommitField {
            id: description

            value: root.bind.description ?? ""
            placeholder: "What it is for (optional)"
            onCommitted: text => root.set({ description: text.trim() })
        }
    }

    Flag {
        label: "Repeat while held"
        checked: root.bind.repeat === true
        onClicked: root.set({ repeat: !checked })
    }

    Flag {
        label: "Works on the lock screen"
        checked: root.bind.locked === true
        onClicked: root.set({ locked: !checked })
    }

    ActionRow {
        searchable: false
        padding: Theme.px(8)
        label: "Remove this keybind"
        button: "Remove"
        icon: Icons.trash
        onTriggered: root.editor.remove(root.index)
    }
}
