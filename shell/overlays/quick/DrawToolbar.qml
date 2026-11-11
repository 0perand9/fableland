import QtQuick
import QtQuick.Effects
import qs.core
import qs.widgets

// The drawing toolbar: the tools, the ink, the history, the board and the way
// out. It shows the state it is given and reports what is clicked.
Rectangle {
    id: toolbar

    // The tools, each { id, icon, name, key }.
    property var tools: []
    property string tool: ""
    property color ink
    // The current stroke width in design units; the ink dot is drawn that size.
    property real thickness: 4
    property bool inkOpen: false
    property bool board: false
    property bool canUndo: false
    property bool canRedo: false
    property bool blank: true

    signal toolPicked(string tool)
    signal inkClicked
    signal undo
    signal redo
    signal clear
    signal boardToggled
    signal save
    signal done

    readonly property real button: Theme.px(36)
    readonly property real gap: Theme.px(2)

    implicitWidth: row.width + Theme.px(20)
    implicitHeight: Theme.px(52)
    radius: height / 2
    color: Theme.alpha(Theme.base, 0.95)
    border.width: 1
    border.color: Theme.border

    component Divider: Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(5)
        height: Theme.px(22)

        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height
            color: Theme.border
        }
    }

    RectangularShadow {
        anchors.fill: parent
        z: -1
        radius: parent.radius
        blur: Theme.px(28)
        offset.y: Theme.px(6)
        color: Theme.shadow
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.px(6)

        Item {
            width: toolRow.width
            height: toolbar.button

            Stretch {
                readonly property int index: toolbar.tools.findIndex(tool => tool.id === toolbar.tool)

                height: parent.height
                targetStart: index * (toolbar.button + toolbar.gap)
                targetEnd: targetStart + toolbar.button
                visible: index >= 0
            }

            Row {
                id: toolRow

                spacing: toolbar.gap

                Repeater {
                    model: toolbar.tools

                    ToolButton {
                        required property var modelData
                        readonly property bool current: modelData.id === toolbar.tool

                        icon: modelData.icon
                        tip: modelData.name + "  ·  " + modelData.key
                        iconColor: current ? Theme.accentText : hovered ? Theme.text : Theme.subtext
                        onClicked: toolbar.toolPicked(modelData.id)
                    }
                }
            }
        }

        Divider {}

        ToolButton {
            // The open popover says it all, and the tip would cover its foot.
            tip: toolbar.inkOpen ? "" : "Colour and width"
            fill: toolbar.inkOpen ? Theme.alpha(Theme.surface2, 0.8) : "transparent"
            onClicked: toolbar.inkClicked()

            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(Math.max(8, Math.min(24, toolbar.thickness)))
                height: width
                radius: width / 2
                color: toolbar.ink
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.5)
            }
        }

        Divider {}

        ToolButton {
            icon: Icons.undo
            tip: "Undo  ·  Ctrl+Z"
            interactive: toolbar.canUndo
            onClicked: toolbar.undo()
        }

        ToolButton {
            icon: Icons.redo
            tip: "Redo  ·  Ctrl+Shift+Z"
            interactive: toolbar.canRedo
            onClicked: toolbar.redo()
        }

        ToolButton {
            icon: Icons.trash
            tip: "Clear  ·  Del"
            iconColor: Theme.red
            interactive: !toolbar.blank
            onClicked: toolbar.clear()
        }

        Divider {}

        ToolButton {
            icon: Icons.dotsGrid
            tip: "Board  ·  B"
            fill: toolbar.board ? Theme.alpha(Theme.accent, 0.2) : "transparent"
            iconColor: toolbar.board ? Theme.accent : hovered ? Theme.text : Theme.subtext
            onClicked: toolbar.boardToggled()
        }

        ToolButton {
            visible: Daemon.has("capture")
            icon: Icons.screenshot
            tip: "Save a screenshot  ·  Ctrl+S"
            onClicked: toolbar.save()
        }

        Divider {}

        ToolButton {
            icon: Icons.close
            tip: "Done  ·  Esc"
            onClicked: toolbar.done()
        }
    }
}
