import QtQuick
import qs.core
import qs.widgets

// Asked over the whole popup right after Apply: keep the new layout, or go
// back to the previous one, which happens by itself when the time runs out.
Item {
    id: root

    property bool open: false
    // The share of `graceSeconds` that is left.
    property real patience: 1
    property int graceSeconds: 0

    signal keepClicked
    signal goBackClicked

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    // Dims the popup and swallows clicks meant for it.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.alpha(Theme.crust, 0.7)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Theme.px(400)
        height: content.implicitHeight + 2 * Theme.px(24)
        radius: Theme.radius
        color: Theme.base
        border.width: 1
        border.color: Theme.border
        scale: root.open ? 1 : 0.95
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Column {
            id: content

            anchors.centerIn: parent
            width: parent.width - 2 * Theme.px(24)
            spacing: Theme.px(16)

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.px(56)
                height: width

                Ring {
                    anchors.fill: parent
                    thickness: 4
                    value: root.patience
                    color: Theme.yellow
                }

                Txt {
                    anchors.centerIn: parent
                    size: 18
                    bold: true
                    text: Math.ceil(root.patience * root.graceSeconds)
                }
            }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                size: 16
                bold: true
                text: "Keep these display settings?"
            }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                size: 12
                color: Theme.subtext
                text: "If you can't see this properly, wait and the previous settings come back by themselves."
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(8)

                Btn {
                    text: "Go back"
                    icon: Icons.undo
                    onClicked: root.goBackClicked()
                }

                Btn {
                    kind: "filled"
                    text: "Keep"
                    icon: Icons.check
                    onClicked: root.keepClicked()
                }
            }
        }
    }
}
