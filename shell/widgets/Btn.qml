import QtQuick
import qs.core

// A text button with an optional icon.
//   kind: "filled" (the main action), "tonal" (default) or "flat"
Clickable {
    id: root

    property string text: ""
    property string icon: ""
    property string kind: "tonal"
    property color accentColor: Theme.accent
    property real size: 13

    readonly property color foreground: kind === "filled" ? Theme.accentText : kind === "flat" ? accentColor : Theme.text

    implicitWidth: row.implicitWidth + Theme.px(28)
    implicitHeight: Theme.px(36)
    fill: kind === "filled" ? accentColor : kind === "flat" ? "transparent" : Theme.alpha(Theme.surface1, 0.7)
    tint: kind === "filled" ? Theme.accentText : Theme.text
    opacity: interactive ? 1 : 0.45

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.px(8)

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: root.size + 4
            color: root.foreground
        }

        Txt {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            size: root.size
            bold: true
            color: root.foreground
        }
    }
}
