import QtQuick
import qs.core
import qs.widgets

// The first page: the system you are on, where to go next and what Fableland is made of.
Item {
    id: view

    // Asks the guide to show another section.
    signal navigate(string section)

    readonly property var info: Daemon.sysinfo
    readonly property var facts: [
        { icon: (info.os ?? "").indexOf("NixOS") >= 0 ? Icons.nixos : Icons.linux, caption: "System", value: info.os },
        { icon: Icons.cpu, caption: "Processor", value: info.cpu },
        { icon: Icons.chip, caption: "Kernel", value: info.kernel },
        { icon: Icons.gpu, caption: "Graphics", value: info.gpu },
        { icon: Icons.hyprland, caption: "Compositor", value: info.compositor },
        { icon: Icons.tag, caption: "Fableland", value: info.version }
    ]
    readonly property var shortcuts: [
        { icon: Icons.compass, title: "Take the tour", text: "Every part of the shell, ready to try", section: "tour" },
        { icon: Icons.keybinds, title: "Keybinds", text: "Your shortcuts, live and searchable", section: "keys" },
        { icon: Icons.terminal, title: "Command line", text: "The fable command and binding keys", section: "commands" },
        { icon: Icons.palette, title: "Colours", text: "How the wallpaper themes everything", section: "theme" }
    ]
    readonly property var parts: [
        { icon: Icons.sparkle, title: "fable", text: "One small daemon does all the system work and publishes what it knows.", url: "" },
        { icon: Icons.dashboard, title: "Quickshell", text: "Draws the bar, the pop-ups and the overlays: a pure view of the daemon.", url: "https://quickshell.org" },
        { icon: Icons.hyprland, title: "Hyprland", text: "The compositor. Its keybinds reach fable without starting a process.", url: "https://hypr.land" },
        { icon: Icons.palette, title: "matugen", text: "Turns the wallpaper into the palette every surface is painted with.", url: "https://github.com/InioX/matugen" }
    ]

    Column {
        width: parent.width
        spacing: Theme.px(20)

        Card {
            id: hero

            width: parent.width
            height: Theme.px(172)

            Item {
                id: identity

                width: Theme.px(210)
                height: parent.height

                Rectangle {
                    id: avatar

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.px(22)
                    width: Theme.px(76)
                    height: Theme.px(76)
                    radius: width / 2
                    color: Theme.alpha(Theme.accent, 0.14)
                    border.width: Theme.px(2)
                    border.color: Theme.alpha(Theme.accent, 0.6)

                    Icon {
                        anchors.centerIn: parent
                        visible: !picture.loaded
                        text: Icons.user
                        size: 38
                        color: Theme.accent
                    }

                    RoundImage {
                        id: picture

                        anchors.fill: parent
                        anchors.margins: Theme.px(5)
                        radius: width / 2
                        color: "transparent"
                        source: Fmt.file(view.info.avatar ?? "")
                    }
                }

                Txt {
                    id: user

                    anchors.top: avatar.bottom
                    anchors.topMargin: Theme.px(10)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: view.info.user ?? ""
                    size: 18
                    bold: true
                }

                Txt {
                    anchors.top: user.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "@" + (view.info.host ?? "")
                    size: 12
                    color: Theme.subtext
                }
            }

            Rectangle {
                id: divider

                anchors.left: identity.right
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height - Theme.px(48)
                color: Theme.border
            }

            Grid {
                anchors.left: divider.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(28)
                anchors.rightMargin: Theme.px(20)
                anchors.verticalCenter: parent.verticalCenter
                columns: 2
                columnSpacing: Theme.px(20)
                rowSpacing: Theme.px(10)

                Repeater {
                    model: view.facts

                    Fact {
                        required property var modelData

                        width: (parent.width - parent.columnSpacing) / 2
                        icon: modelData.icon
                        caption: modelData.caption
                        value: modelData.value ?? ""
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.px(6)

            Txt {
                text: "Welcome to Fableland"
                size: 22
                bold: true
            }

            Txt {
                width: parent.width
                text: "A bar, pop-ups and overlays for Hyprland, all drawn from one daemon. Everything you see can be opened from the bar, from a keybind or from a terminal with the fable command."
                size: 13
                color: Theme.subtext
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }
        }

        Column {
            width: parent.width
            spacing: Theme.px(10)

            Heading {
                text: "Start here"
            }

            Row {
                id: starters

                width: parent.width
                spacing: Theme.px(12)

                Repeater {
                    model: view.shortcuts

                    Tile {
                        required property var modelData

                        width: (starters.width - 3 * starters.spacing) / 4
                        implicitHeight: Theme.px(84)
                        icon: modelData.icon
                        title: modelData.title
                        text: modelData.text
                        onClicked: view.navigate(modelData.section)
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.px(10)

            Heading {
                text: "Under the hood"
            }

            Grid {
                id: pieces

                width: parent.width
                columns: 2
                spacing: Theme.px(12)

                Repeater {
                    model: view.parts

                    Tile {
                        required property var modelData

                        width: (pieces.width - pieces.spacing) / 2
                        icon: modelData.icon
                        hue: Theme.tertiary
                        title: modelData.title
                        text: modelData.text
                        interactive: modelData.url !== ""
                        trailing: modelData.url !== "" ? Icons.openExternal : ""
                        onClicked: Daemon.send("misc.open", { target: modelData.url })
                    }
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        spacing: Theme.px(8)

        Repeater {
            model: [{ key: "Tab", does: "next section" }, { key: "Esc", does: "close" }]

            Row {
                required property var modelData

                spacing: Theme.px(8)
                rightPadding: Theme.px(14)

                KeyCap {
                    label: parent.modelData.key
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.does
                    size: 12
                    color: Theme.dim
                }
            }
        }
    }
}
