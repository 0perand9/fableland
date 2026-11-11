import QtQuick
import qs.core

// A single-line text field with an optional leading icon.
FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool clearable: true
    property real size: 14
    property color accentColor: Theme.accent

    signal accepted

    implicitWidth: Theme.px(260)
    implicitHeight: Theme.px(42)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.surface0, 0.6)
        border.width: 1
        border.color: input.activeFocus ? Theme.alpha(root.accentColor, 0.7) : Theme.border

        Behavior on border.color {
            ColorAnimation { duration: Theme.fast }
        }
    }

    Icon {
        id: leading

        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: root.size + 4
        color: input.activeFocus ? root.accentColor : Theme.dim
    }

    TextInput {
        id: input

        anchors.left: leading.visible ? leading.right : parent.left
        anchors.right: clear.visible ? clear.left : parent.right
        anchors.leftMargin: Theme.px(leading.visible ? 10 : 14)
        anchors.rightMargin: Theme.px(clear.visible ? 4 : 14)
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        clip: true
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(root.size)
        selectByMouse: true
        selectionColor: Theme.alpha(root.accentColor, 0.4)
        selectedTextColor: Theme.text
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()
    }

    Txt {
        anchors.fill: input
        visible: input.text === "" && input.preeditText === ""
        text: root.placeholder
        size: root.size
        color: Theme.dim
    }

    IconBtn {
        id: clear

        visible: root.clearable && input.text !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(6)
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.close
        size: 28
        iconColor: Theme.dim
        onClicked: {
            input.text = "";
            input.forceActiveFocus();
        }
    }
}
