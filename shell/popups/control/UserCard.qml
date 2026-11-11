import QtQuick
import qs.core
import qs.widgets

// Who is logged in, on which machine, and how long it has been up. The card
// may be given any height: with room to spare it also lists what the machine
// is made of, as many lines as fit.
Card {
    id: root

    readonly property var info: Daemon.sysinfo
    readonly property string user: info.user || Daemon.power.user || "user"
    readonly property string host: info.host || Daemon.power.host || ""
    // Advanced every half minute while the card is shown.
    property real now: Date.now()
    // Minutes since boot; 0 until the boot time is known.
    readonly property int minutesUp: Daemon.power.bootTime > 0 ? Math.max(0, Math.floor((now / 1000 - Daemon.power.bootTime) / 60)) : 0
    // The two largest units: days and hours once a day has passed, else hours and minutes.
    readonly property bool days: minutesUp >= 24 * 60
    readonly property int major: days ? Math.floor(minutesUp / 1440) : Math.floor(minutesUp / 60)
    readonly property int minor: days ? Math.floor(minutesUp % 1440 / 60) : minutesUp % 60

    readonly property var facts: [
        { icon: (info.os ?? "").startsWith("NixOS") ? Icons.nixos : Icons.linux, text: info.os },
        { icon: Icons.chip, text: info.kernel ? "Linux " + info.kernel : "" },
        { icon: (info.compositor ?? "").startsWith("Hyprland") ? Icons.hyprland : Icons.window, text: info.compositor },
        { icon: Icons.cpu, text: info.cpu },
        { icon: Icons.gpu, text: info.gpu }
    ].filter(fact => !!fact.text)
    readonly property int factHeight: Theme.px(22)
    // How many facts fit below the headline (the rule above them takes its share).
    readonly property int factsShown: Math.max(0, Math.min(facts.length, Math.floor((height - 2 * Theme.pad - headline.height - rule.height) / factHeight)))

    implicitHeight: headline.height + 2 * Theme.pad

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // One box of the uptime display: a number over its unit.
    component Unit: Rectangle {
        id: unit

        property int value: 0
        property string label: ""
        property color hue: Theme.accent

        width: Theme.px(46)
        height: Theme.px(50)
        radius: Theme.radiusSmall
        color: Theme.alpha(hue, 0.1)
        border.width: 1
        border.color: Theme.alpha(hue, 0.25)

        Column {
            anchors.centerIn: parent

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (unit.value < 10 ? "0" : "") + unit.value
                size: 18
                bold: true
                color: unit.hue
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: unit.label
                size: 8
                bold: true
                color: Theme.subtext
            }
        }
    }

    Column {
        x: Theme.pad
        width: parent.width - 2 * x
        anchors.verticalCenter: parent.verticalCenter

        // ── who and for how long ──
        Item {
            id: headline

            width: parent.width
            height: Theme.px(66)

            Rectangle {
                id: avatar

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(56)
                height: width
                radius: width / 2
                color: Theme.alpha(Theme.accent, 0.18)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.4)

                // The initial stands in until (or unless) there is a picture.
                Txt {
                    anchors.centerIn: parent
                    visible: !picture.loaded
                    text: root.user.charAt(0).toUpperCase()
                    size: 24
                    bold: true
                    color: Theme.accent
                }

                RoundImage {
                    id: picture

                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    source: Fmt.file(root.info.avatar ?? "")
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: Theme.px(14)
                anchors.right: uptime.left
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(1)

                Txt {
                    width: parent.width
                    text: root.user
                    size: 18
                    bold: true
                }

                Txt {
                    width: parent.width
                    text: root.host
                    size: 12
                    color: Theme.subtext
                }

                // Without room for the list below, the system still gets a line.
                Txt {
                    width: parent.width
                    visible: root.factsShown === 0 && text !== ""
                    text: root.info.os ?? ""
                    size: 11
                    color: Theme.dim
                }
            }

            Column {
                id: uptime

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(4)

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "UPTIME"
                    size: 9
                    bold: true
                    color: Theme.dim
                    font.letterSpacing: Theme.px(1.5)
                }

                Row {
                    spacing: Theme.px(5)

                    Unit {
                        value: root.major
                        label: root.days ? "DAYS" : "HR"
                        hue: Theme.accent
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        size: 18
                        bold: true
                        color: Theme.accent

                        SequentialAnimation on opacity {
                            running: root.visible
                            loops: Animation.Infinite

                            NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
                        }
                    }

                    Unit {
                        value: root.minor
                        label: root.days ? "HR" : "MIN"
                        hue: Theme.secondary
                    }
                }
            }
        }

        // ── what the machine is made of ──
        Item {
            id: rule

            width: parent.width
            height: Theme.px(25)
            visible: root.factsShown > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Theme.border
            }
        }

        Repeater {
            model: root.factsShown

            Row {
                id: fact

                required property int index
                readonly property var line: root.facts[index] ?? ({})

                width: parent.width
                height: root.factHeight
                spacing: Theme.px(10)

                Icon {
                    id: glyph

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(18)
                    text: fact.line.icon ?? ""
                    size: 15
                    color: Theme.dim
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - glyph.width - parent.spacing
                    text: fact.line.text ?? ""
                    size: 11
                    color: Theme.subtext
                }
            }
        }
    }
}
