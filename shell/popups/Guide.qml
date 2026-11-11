import QtQuick
import qs.core
import qs.widgets
import qs.popups.guide

// The help centre: what you are running, a tour of every part of the shell, the
// live keybind cheat-sheet, the `fable` command line and how the colours work.
// `fable toggle guide tour|keys|commands|theme` opens it on that section.
PopupPage {
    id: page

    readonly property var sections: [
        { id: "overview", label: "Overview", icon: Icons.home, view: overview },
        { id: "tour", label: "Tour", icon: Icons.compass, view: tour },
        { id: "keys", label: "Keybinds", icon: Icons.keybinds, view: keybinds },
        { id: "commands", label: "Command line", icon: Icons.terminal, view: commands },
        { id: "theme", label: "Colours", icon: Icons.palette, view: theming }
    ]
    // Follows `arg` until the user picks a section.
    property int current: sectionIndex(arg)
    readonly property int updates: Daemon.updates.count
    // 0 → 1 once, as the popup opens: the sidebar and the content slide into place.
    property real intro: 0

    function sectionIndex(id) {
        return Math.max(0, sections.findIndex(section => section.id === id));
    }

    function step(by) {
        current = (current + by + sections.length) % sections.length;
    }

    implicitWidth: Theme.px(1200)
    implicitHeight: Theme.px(750)
    onArgChanged: current = sectionIndex(arg)
    Keys.onTabPressed: step(1)
    Keys.onBacktabPressed: step(-1)

    NumberAnimation on intro {
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Easing.OutCubic
    }

    Backdrop {
        anchors.fill: parent
    }

    Component { id: overview; Overview {} }
    Component { id: tour; Tour {} }
    Component { id: keybinds; Keybinds {} }
    Component { id: commands; Commands {} }
    Component { id: theming; Theming {} }

    Card {
        id: sidebar

        x: Theme.px(20)
        y: Theme.px(20)
        width: Theme.px(220)
        height: parent.height - 2 * y
        opacity: page.intro
        transform: Translate { x: Theme.px(-24) * (1 - page.intro) }

        Rectangle {
            id: emblem

            x: Theme.px(16)
            y: Theme.px(18)
            width: Theme.px(38)
            height: Theme.px(38)
            radius: Theme.radiusSmall
            color: Theme.accent

            Icon {
                anchors.centerIn: parent
                text: Icons.book
                size: 21
                color: Theme.accentText
            }
        }

        Column {
            anchors.left: emblem.right
            anchors.leftMargin: Theme.px(12)
            anchors.verticalCenter: emblem.verticalCenter

            Txt {
                text: "Fableland"
                size: 15
                bold: true
            }

            Txt {
                text: Daemon.sysinfo.version ? "v" + Daemon.sysinfo.version : "guide"
                size: 11
                color: Theme.subtext
            }
        }

        Rectangle {
            id: rule

            anchors.top: emblem.bottom
            anchors.topMargin: Theme.px(16)
            x: Theme.px(16)
            width: parent.width - 2 * x
            height: 1
            color: Theme.border
        }

        Item {
            id: nav

            readonly property int rowHeight: Theme.px(44)

            anchors.top: rule.bottom
            anchors.topMargin: Theme.px(14)
            x: Theme.px(12)
            width: parent.width - 2 * x
            height: page.sections.length * rowHeight

            Stretch {
                vertical: true
                width: parent.width
                radius: Theme.radiusSmall
                targetStart: page.current * nav.rowHeight
                targetEnd: targetStart + nav.rowHeight
            }

            Repeater {
                model: page.sections

                Item {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === page.current
                    readonly property color foreground: isCurrent ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

                    y: index * nav.rowHeight
                    width: nav.width
                    height: nav.rowHeight

                    Row {
                        // The current entry leans towards the content.
                        x: Theme.px(entry.isCurrent ? 18 : 12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(12)

                        Behavior on x {
                            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.icon
                            size: 18
                            color: entry.foreground
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            size: 13
                            bold: true
                            color: entry.foreground

                            Behavior on color {
                                ColorAnimation { duration: Theme.normal }
                            }
                        }
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.current = entry.index
                    }
                }
            }
        }

        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(14)
            x: Theme.px(12)
            width: parent.width - 2 * x
            spacing: Theme.px(10)

            Btn {
                visible: page.updates > 0
                width: parent.width
                icon: Icons.update
                text: page.updates === 1 ? "1 update" : page.updates + " updates"
                kind: "flat"
                accentColor: Theme.green
                fill: Theme.alpha(Theme.green, 0.12)
                onClicked: Ui.open("updates")
            }

            Item {
                width: parent.width
                height: Theme.px(28)

                Txt {
                    x: Theme.px(4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open at start-up"
                    size: 12
                    color: Theme.subtext
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Daemon.setting("openGuideAtStartup", false)
                    onToggled: checked => Daemon.setSetting("openGuideAtStartup", checked)
                }
            }

            Row {
                width: parent.width
                spacing: Theme.px(8)

                Btn {
                    width: (parent.width - parent.spacing) / 2
                    icon: Icons.settings
                    text: "Settings"
                    size: 12
                    onClicked: Ui.open("settings")
                }

                Btn {
                    width: (parent.width - parent.spacing) / 2
                    icon: Icons.close
                    text: "Close"
                    size: 12
                    onClicked: page.close()
                }
            }
        }
    }

    Loader {
        id: content

        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.px(28)
        anchors.rightMargin: Theme.px(28)
        anchors.topMargin: Theme.px(20)
        anchors.bottomMargin: Theme.px(20)
        focus: true
        sourceComponent: page.sections[page.current].view
        transform: Translate { id: rise }
        onLoaded: arrive.restart()
    }

    // Each section fades in while rising into place, the first one together with the popup.
    ParallelAnimation {
        id: arrive

        NumberAnimation { target: rise; property: "y"; from: Theme.px(14); to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: Theme.normal }
    }

    // Sections that link to another one ask for it by id.
    Connections {
        target: content.item
        ignoreUnknownSignals: true

        function onNavigate(section) {
            page.current = page.sectionIndex(section);
        }
    }
}
