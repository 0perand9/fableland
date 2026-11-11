import QtQuick
import qs.core
import qs.widgets

// The `fable` command line, and how to put its commands on keys.
Item {
    id: view

    // Asks the guide to show another section.
    signal navigate(string section)

    readonly property int gutter: Theme.px(12)
    readonly property var examples: [
        { feature: "clipboard", code: 'hl.bind("SUPER + V", hl.dsp.event("fable toggle clipboard"))' },
        { feature: "capture", code: 'hl.bind("SUPER + SHIFT + S", hl.dsp.event("fable capture region"))' },
        { code: 'hl.bind("XF86AudioRaiseVolume", hl.dsp.event("fable volume +5"), { repeating = true, locked = true })' }
    ].filter(example => Daemon.has(example.feature ?? "")).map(example => example.code)
    // The reference, as two columns of groups. A command of a feature
    // (Daemon.has) names it, and is left out while that is off.
    readonly property var reference: everything.map(column => column.map(group => Object.assign({}, group, { commands: group.commands.filter(command => Daemon.has(command.feature ?? "")) })))
    readonly property var everything: [
        [
            {
                title: "Pop-ups", note: "Pop-ups: " + Ui.popups.join(", ") + ".",
                commands: [
                    { cmd: "fable toggle <popup> [arg]", about: "Open a pop-up, or close it when it is already open" },
                    { cmd: "fable open <popup> [arg]", about: "Open a pop-up, or switch it to another tab" },
                    { cmd: "fable close", about: "Close whatever is open" }
                ]
            },
            {
                title: "Session", note: "",
                commands: [
                    { cmd: "fable lock", about: "Lock the session", feature: "lock" },
                    { cmd: "fable logout | suspend | reboot | poweroff", about: "Leave it, one way or another" }
                ]
            },
            {
                title: "Under the surface", note: "",
                commands: [
                    { cmd: "fable watch", about: "Print every state change and event as it happens" },
                    { cmd: "fable get <topic>", about: "Print one topic, such as audio or net" },
                    { cmd: "fable call <method> [json]", about: "Call any method of the daemon" },
                    { cmd: "fable daemon [--no-shell] [--shell-dir DIR]", about: "Run the daemon, which starts the shell" }
                ]
            }
        ],
        [
            {
                title: "Sound, light and media", note: "N is a percentage: +5 and -5 step, 40 sets.",
                commands: [
                    { cmd: "fable volume <+N|-N|N|mute>", about: "The default output" },
                    { cmd: "fable mic <+N|-N|N|mute>", about: "The default input" },
                    { cmd: "fable brightness <+N|-N|N>", about: "The screen's backlight" },
                    { cmd: "fable media <play-pause|next|prev>", about: "The active player" }
                ]
            },
            {
                title: "Desktop", note: "",
                commands: [
                    { cmd: "fable workspace <N>", about: "Switch to a workspace" },
                    { cmd: "fable capture <region|full|edit|ocr|qr|record|stop>", about: "Screenshots, text and QR recognition, screen recording", feature: "capture" },
                    { cmd: "fable wallpaper <next|prev|random|PATH>", about: "Change the wallpaper", feature: "wallpaper" },
                    { cmd: "fable dnd [on|off]", about: "Do not disturb; toggles when given nothing", feature: "notifications" },
                    { cmd: "fable reload", about: "Restart the shell" },
                    { cmd: "fable restart", about: "Restart the daemon and the shell: after an update, the new build" }
                ]
            }
        ]
    ]

    PageTitle {
        id: title

        width: parent.width
        title: "Command line"
        subtitle: "Everything the shell does is a fable command: in a terminal, a script or a keybind."
    }

    Scroll {
        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(18)
        // Wider than the cards, so that the scroll indicator runs beside them.
        width: parent.width + view.gutter

        Column {
            width: parent.width - view.gutter
            spacing: Theme.px(14)

            Card {
                width: parent.width
                implicitHeight: binding.implicitHeight + Theme.px(32)

                Column {
                    id: binding

                    x: Theme.px(16)
                    y: Theme.px(16)
                    width: parent.width - 2 * x
                    spacing: Theme.px(10)

                    Row {
                        spacing: Theme.px(10)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.keybinds
                            size: 20
                            color: Theme.accent
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Put a command on a key"
                            size: 15
                            bold: true
                        }
                    }

                    Txt {
                        width: parent.width
                        text: "In Hyprland's Lua config a bind can hand the command straight to the daemon. No process is started, so it is instant:"
                        size: 12
                        color: Theme.subtext
                        wrapMode: Text.WordWrap
                    }

                    CodeLine {
                        width: parent.width
                        code: 'hl.bind("SUPER + D", hl.dsp.event("fable toggle launcher"))'
                    }

                    Txt {
                        width: parent.width
                        text: "What follows “fable” is exactly what you would type in a terminal. A few more to start from:"
                        size: 12
                        color: Theme.subtext
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: view.examples

                        CodeLine {
                            required property string modelData

                            width: binding.width
                            code: modelData
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.px(36)

                        Txt {
                            anchors.left: parent.left
                            anchors.right: links.left
                            anchors.rightMargin: Theme.px(12)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Rather not edit the config? Settings keeps keybinds as well."
                            size: 12
                            color: Theme.subtext
                        }

                        Row {
                            id: links

                            anchors.right: parent.right
                            spacing: Theme.px(8)

                            Btn {
                                icon: Icons.keyboard
                                text: "Your keybinds"
                                size: 12
                                onClicked: view.navigate("keys")
                            }

                            Btn {
                                icon: Icons.settings
                                text: "Settings › Keybinds"
                                size: 12
                                onClicked: Ui.open("settings", "keybinds")
                            }
                        }
                    }
                }
            }

            Row {
                id: columns

                width: parent.width
                spacing: Theme.px(14)

                Repeater {
                    model: view.reference

                    Column {
                        required property var modelData

                        width: (columns.width - columns.spacing) / 2
                        spacing: Theme.px(14)

                        Repeater {
                            model: parent.modelData

                            CommandGroup {
                                required property var modelData

                                width: parent.width
                                title: modelData.title
                                commands: modelData.commands
                                note: modelData.note
                            }
                        }
                    }
                }
            }

            // Room below the last card, so it does not sit on the popup's edge.
            Item {
                width: 1
                height: Theme.px(4)
            }
        }
    }
}
