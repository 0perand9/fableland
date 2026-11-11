import QtQuick
import qs.core
import qs.widgets

// A pill that narrows a list to one category and says how many entries it holds.
Clickable {
    id: root

    property string text: ""
    property int count: 0
    property bool active: false

    readonly property color foreground: active ? Theme.accentText : Theme.text

    implicitWidth: content.implicitWidth + Theme.px(24)
    implicitHeight: Theme.px(30)
    radius: height / 2
    fill: active ? Theme.accent : Theme.alpha(Theme.surface0, 0.6)
    tint: foreground
    border.width: 1
    border.color: active ? Theme.accent : Theme.border

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.px(7)

        Txt {
            text: root.text
            size: 12
            bold: true
            color: root.foreground
        }

        Txt {
            text: root.count
            size: 12
            color: Theme.alpha(root.foreground, 0.6)
        }
    }
}
