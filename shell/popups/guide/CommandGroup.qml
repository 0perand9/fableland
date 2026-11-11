import QtQuick
import qs.core
import qs.widgets

// A titled card listing related `fable` commands and what each one does.
Card {
    id: root

    property string title: ""
    // [{ cmd: "fable close", about: "Close whatever is open" }]
    property var commands: []
    // Small print under the list, e.g. the values an argument takes.
    property string note: ""

    implicitHeight: content.implicitHeight + Theme.px(28)

    Column {
        id: content

        x: Theme.px(16)
        y: Theme.px(14)
        width: parent.width - 2 * x
        spacing: Theme.px(10)

        Heading {
            text: root.title
        }

        Repeater {
            model: root.commands

            Column {
                required property var modelData

                width: content.width
                spacing: Theme.px(1)

                Txt {
                    width: parent.width
                    text: parent.modelData.cmd
                    size: 12
                    bold: true
                }

                Txt {
                    width: parent.width
                    text: parent.modelData.about
                    size: 11
                    color: Theme.subtext
                }
            }
        }

        Txt {
            visible: root.note !== ""
            width: parent.width
            text: root.note
            size: 11
            color: Theme.dim
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }
}
