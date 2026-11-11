import QtQuick
import qs.core
import qs.widgets

// One key of a shortcut, drawn as a key cap: a face sitting on a darker side.
Item {
    id: root

    property string label: ""
    // The key that completes the shortcut stands out from its modifiers.
    property bool primary: false

    readonly property int depth: Theme.px(3)

    implicitWidth: Math.max(implicitHeight - depth, text.implicitWidth + Theme.px(16))
    implicitHeight: Theme.px(27)

    Rectangle {
        anchors.fill: parent
        radius: face.radius
        color: root.primary ? Theme.alpha(Theme.accent, 0.4) : Theme.alpha(Theme.text, 0.16)
    }

    Rectangle {
        id: face

        width: parent.width
        height: parent.height - root.depth
        radius: Theme.px(6)
        color: root.primary ? Theme.mix(Theme.surface1, Theme.accent, 0.22) : Theme.surface1
        border.width: 1
        border.color: root.primary ? Theme.alpha(Theme.accent, 0.5) : Theme.alpha(Theme.text, 0.1)

        Txt {
            id: text

            anchors.centerIn: parent
            text: root.label
            size: 11
            bold: true
            color: root.primary ? Theme.text : Theme.subtext
        }
    }
}
