import QtQuick
import qs.core
import qs.widgets

// One line of launcher results: an application, or something the query asked
// for (a calculation, a command, a web search). The list's highlight shows
// through the selected row.
Clickable {
    id: root

    // An entry of the `apps` topic, or an action: { action, value, icon, title, subtitle, verb }.
    property var entry: ({})
    property bool selected: false

    readonly property bool isApp: entry.action === undefined
    readonly property string title: (isApp ? entry.name : entry.title) ?? ""
    readonly property string subtitle: (isApp ? (entry.generic || entry.comment) : entry.subtitle) ?? ""
    // What Enter does to this row; "" for an action that has nothing to act on yet.
    readonly property string verb: isApp ? "Launch" : entry.value !== "" ? entry.verb : ""
    readonly property color foreground: selected ? Theme.accentText : Theme.text
    readonly property color faded: selected ? Theme.alpha(Theme.accentText, 0.75) : Theme.dim

    implicitHeight: Theme.px(60)
    radius: Theme.radius
    fill: hovered && !selected ? Theme.alpha(Theme.surface1, 0.45) : "transparent"
    tint: foreground

    Rectangle {
        id: badge

        x: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(40)
        height: Theme.px(40)
        radius: Theme.px(12)
        color: root.selected ? Theme.crust : Theme.alpha(Theme.surface1, 0.55)
        scale: root.selected ? 1.1 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }

        AppIcon {
            anchors.centerIn: parent
            visible: root.isApp
            icon: root.isApp ? (root.entry.icon ?? "") : ""
            size: 26
        }

        Icon {
            anchors.centerIn: parent
            visible: !root.isApp
            text: root.isApp ? "" : (root.entry.icon ?? "")
            size: 22
            color: Theme.accent
        }
    }

    Column {
        anchors.left: badge.right
        // The selected row leans in a little.
        anchors.leftMargin: Theme.px(root.selected ? 20 : 14)
        anchors.right: hint.left
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(1)

        Behavior on anchors.leftMargin {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Txt {
            width: parent.width
            text: root.title
            size: 14
            bold: root.selected
            color: root.foreground
        }

        Txt {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            size: 11
            color: root.faded
        }
    }

    Row {
        id: hint

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(6)
        visible: root.selected && root.verb !== ""

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.verb
            size: 11
            bold: true
            color: root.faded
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.enter
            size: 15
            color: root.faded
        }
    }
}
