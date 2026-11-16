import QtQuick
import qs.core
import qs.widgets

// The bottom line: where the edited layout stands, and Revert and Apply.
// Keeping an applied layout is asked by KeepDialog.
Item {
    id: root

    // The layout being edited differs from the one in use.
    property bool dirty: false
    // An Apply is on its way to the daemon.
    property bool busy: false
    // Why the last Apply did not work.
    property string failure: ""
    // More than one monitor is affected.
    property bool several: false

    signal applyClicked
    signal revertClicked

    implicitHeight: Theme.px(36)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.dirty || root.failure !== ""
            width: Theme.px(8)
            height: width
            radius: width / 2
            color: root.failure !== "" ? Theme.red : Theme.yellow
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - buttons.width - Theme.px(60))
            size: 12
            color: root.failure !== "" ? Theme.red : root.dirty ? Theme.text : Theme.dim
            text: root.failure !== "" ? root.failure : root.dirty ? "Not applied yet" : "This is the layout in use"
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        spacing: Theme.px(8)

        Btn {
            text: "Revert"
            icon: Icons.undo
            interactive: root.dirty
            onClicked: root.revertClicked()
        }

        Btn {
            kind: "filled"
            text: root.several ? "Apply all" : "Apply"
            icon: Icons.check
            interactive: root.dirty && !root.busy
            onClicked: root.applyClicked()
        }
    }
}
