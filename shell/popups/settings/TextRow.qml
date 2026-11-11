import QtQuick
import qs.core
import qs.widgets

// A text setting. Written on Enter or when the field loses focus.
SettingRow {
    id: root

    property string placeholder: ""
    property string icon: directory ? Icons.folder : ""
    // Keep the value masked until the user asks to see it (API keys).
    property bool secret: false
    property bool revealed: false
    // The value is a directory: complete it while typing.
    property bool directory: false
    // The field's width when it sits beside the label (`stacked: false`).
    property real fieldWidth: Theme.px(150)

    stacked: true
    onActivated: {
        entry.forceActiveFocus();
        entry.input.selectAll();
    }

    Column {
        width: root.fieldWidth

        Row {
            width: parent.width
            spacing: Theme.px(4)

            CommitField {
                id: entry

                width: parent.width - (reveal.visible ? reveal.width + parent.spacing : 0)
                value: String(Daemon.setting(root.path, "") ?? "")
                placeholder: root.placeholder
                icon: root.icon
                password: root.secret && !root.revealed
                // A directory is stored without the slash that completing it leaves at the end.
                onCommitted: text => Daemon.setSetting(root.path, root.directory ? text.trim().replace(/(.)\/+$/, "$1") : text.trim())
                Keys.onTabPressed: event => event.accepted = completion.item !== null && completion.item.complete()
                Keys.onDownPressed: event => event.accepted = completion.item !== null && completion.item.step(1)
                Keys.onUpPressed: event => event.accepted = completion.item !== null && completion.item.step(-1)
            }

            IconBtn {
                id: reveal

                visible: root.secret
                anchors.verticalCenter: parent.verticalCenter
                icon: root.revealed ? Icons.eyeOff : Icons.eye
                size: 30
                iconColor: Theme.subtext
                onClicked: root.revealed = !root.revealed
            }
        }

        Loader {
            id: completion

            width: parent.width
            active: root.directory
            sourceComponent: PathCompletion {
                field: entry
            }
        }
    }
}
