import QtQuick
import qs.core
import qs.widgets

// Who is asked for what: the user's picture and name, how unlocking is going,
// and the password pill.
Row {
    id: root

    required property Auth auth
    property bool capsLock: false

    readonly property bool failed: auth.failure !== ""
    readonly property color stateColor: failed ? Theme.red : auth.checking ? Theme.accent : Theme.text
    readonly property string status: auth.checking ? (auth.notice || "Checking…") : failed ? auth.failure : auth.password !== "" ? "Enter to unlock" : "Locked"

    function shake() {
        pill.shake();
    }

    spacing: Theme.px(32)

    RoundImage {
        id: avatar

        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(170)
        height: width
        radius: width / 2
        source: Fmt.file(Daemon.sysinfo.avatar ?? "")
        border.width: Theme.px(3)
        border.color: root.failed || root.auth.checking ? root.stateColor : Theme.alpha(Theme.text, 0.5)

        Behavior on border.color {
            ColorAnimation { duration: Theme.normal }
        }

        Icon {
            anchors.centerIn: parent
            visible: !avatar.loaded
            text: Icons.user
            size: 80
            color: Theme.subtext
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(16)

        Txt {
            text: Daemon.sysinfo.user || Daemon.power.user || ""
            size: 28
            bold: true
        }

        Row {
            spacing: Theme.px(12)

            Rectangle {
                id: badge

                readonly property color hue: root.failed ? Theme.red : Theme.accent

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(36)
                height: width
                radius: width / 2
                color: Theme.alpha(hue, 0.15)
                border.width: 1
                border.color: hue

                Icon {
                    anchors.centerIn: parent
                    visible: !root.auth.checking
                    text: Icons.lock
                    size: 18
                    color: badge.hue
                }

                Spinner {
                    anchors.centerIn: parent
                    visible: root.auth.checking
                    width: Theme.px(20)
                    height: width
                    color: badge.hue
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.status.toUpperCase()
                size: 14
                font.letterSpacing: Theme.px(2)
                color: root.stateColor
            }
        }

        PasswordPill {
            id: pill

            text: root.auth.password
            busy: root.auth.checking
            failed: root.failed

            // Hangs below the pill without pushing the prompt off centre.
            Row {
                anchors.top: parent.bottom
                anchors.topMargin: Theme.px(12)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(6)
                opacity: root.capsLock ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.warning
                    size: 15
                    color: Theme.yellow
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Caps Lock is on"
                    size: 12
                    color: Theme.yellow
                }
            }
        }
    }
}
