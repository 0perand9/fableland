import QtQuick
import qs.core
import qs.widgets

// The bottom line: where the edited layout stands, and the buttons that settle
// it — Revert and Apply, or Go back and Keep while a just applied layout waits
// to be confirmed.
Item {
    id: root

    // The layout being edited differs from the one in use.
    property bool dirty: false
    // An Apply is on its way to the daemon.
    property bool busy: false
    // Why the last Apply did not work.
    property string failure: ""
    // The applied layout waits to be kept; `patience` is the share of the
    // `graceSeconds` that is left.
    property bool confirming: false
    property real patience: 1
    property int graceSeconds: 0
    // More than one monitor is affected.
    property bool several: false

    signal applyClicked
    signal revertClicked
    signal keepClicked
    signal goBackClicked

    implicitHeight: Theme.px(36)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)

        Ring {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.confirming
            implicitWidth: Theme.px(22)
            implicitHeight: Theme.px(22)
            thickness: 3
            value: root.patience
            color: Theme.yellow
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.confirming && (root.dirty || root.failure !== "")
            width: Theme.px(8)
            height: width
            radius: width / 2
            color: root.failure !== "" ? Theme.red : Theme.yellow
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - buttons.width - Theme.px(60))
            size: 12
            color: root.failure !== "" ? Theme.red : root.confirming || root.dirty ? Theme.text : Theme.dim
            text: {
                if (root.failure !== "")
                    return root.failure;
                if (root.confirming)
                    return "Keep this layout? Going back in " + Math.ceil(root.patience * root.graceSeconds) + " s";
                return root.dirty ? "Not applied yet" : "This is the layout in use";
            }
        }
    }

    Row {
        id: buttons

        anchors.right: parent.right
        spacing: Theme.px(8)

        Btn {
            text: root.confirming ? "Go back" : "Revert"
            icon: Icons.undo
            interactive: root.confirming || root.dirty
            onClicked: root.confirming ? root.goBackClicked() : root.revertClicked()
        }

        Btn {
            kind: "filled"
            text: root.confirming ? "Keep" : root.several ? "Apply all" : "Apply"
            icon: Icons.check
            interactive: root.confirming || (root.dirty && !root.busy)
            onClicked: root.confirming ? root.keepClicked() : root.applyClicked()
        }
    }
}
