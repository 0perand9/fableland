import QtQuick
import qs.core
import qs.widgets

// Asks for the password of a secured network. It takes the hub's place while
// it is needed: Enter connects, Escape gives up.
Core {
    id: root

    property string ssid: ""
    property color hue: Theme.accent
    // Show the password as typed instead of dots.
    property bool revealed: false

    signal accepted(string password)
    signal cancelled

    implicitWidth: Theme.px(236)
    implicitHeight: Theme.px(236)

    // Every prompt starts empty and hidden again.
    onSsidChanged: {
        field.text = "";
        revealed = false;
    }
    Keys.onEscapePressed: cancelled()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.mix(Theme.base, Theme.surface0, 0.8)
        border.width: Theme.px(2)
        border.color: Theme.alpha(root.hue, 0.7)
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(8)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.lock
            size: 26
            color: root.hue
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, Theme.px(170))
            text: root.ssid
            size: 14
            bold: true
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.px(4)

            Field {
                id: field

                width: Theme.px(150)
                height: Theme.px(36)
                focus: true
                placeholder: "Password"
                password: !root.revealed
                clearable: false
                size: 12
                accentColor: root.hue
                onAccepted: {
                    if (text !== "")
                        root.accepted(text);
                }
            }

            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.revealed ? Icons.eyeOff : Icons.eye
                size: 30
                iconColor: Theme.subtext
                onClicked: root.revealed = !root.revealed
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Enter connects · Esc cancels"
            size: 10
            color: Theme.dim
        }
    }
}
