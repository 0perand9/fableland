import QtQuick
import qs.core
import qs.widgets

// The picker's filters in one strip: everything, videos, eight colour families
// and the online search, whose chip opens into a text field. The highlight
// stretches from chip to chip and takes the colour of what it selects.
Pill {
    id: bar

    // "all", "video", a colour bucket of the daemon, or "search".
    property string current: "all"
    // Number of wallpapers per filter id; filters without any are dimmed.
    property var counts: ({})
    property alias query: input.text
    property bool searchRunning: false

    readonly property bool searching: current === "search"
    // Filter ids in strip order.
    readonly property var order: chips.map(chip => chip.id).concat("search")
    readonly property var chips: [
        { id: "all", label: "All", icon: Icons.grid },
        { id: "video", label: "Video", icon: Icons.video },
        { id: "red", label: "Red" },
        { id: "orange", label: "Orange" },
        { id: "yellow", label: "Yellow" },
        { id: "green", label: "Green" },
        { id: "blue", label: "Blue" },
        { id: "purple", label: "Purple" },
        { id: "pink", label: "Pink" },
        { id: "mono", label: "Mono" }
    ]
    // The selected chip; the highlight sits behind it.
    property Item selection: null

    signal selected(string id)
    signal searchRequested(string query)
    signal stopRequested

    function hue(id) {
        switch (id) {
        case "red": return Theme.red;
        case "orange": return Theme.peach;
        case "yellow": return Theme.yellow;
        case "green": return Theme.green;
        case "blue": return Theme.blue;
        case "purple": return Theme.mauve;
        case "pink": return Theme.pink;
        case "mono": return Theme.subtext;
        default: return Theme.accent;
        }
    }

    // Put the cursor in the search field, adding `text` to what is there.
    function type(text) {
        input.forceActiveFocus();
        input.insert(input.length, text);
    }

    implicitWidth: row.width + 2 * inset

    onSearchingChanged: {
        if (searching)
            input.forceActiveFocus();
    }

    Stretch {
        y: bar.inset
        height: bar.height - 2 * bar.inset
        visible: bar.selection !== null
        targetStart: bar.selection ? row.x + bar.selection.x : 0
        targetEnd: targetStart + (bar.selection ? bar.selection.width : 0)
        // The search field is a field, not a button: outlined instead of filled.
        color: bar.searching ? Theme.alpha(Theme.text, 0.08) : bar.hue(bar.current)
        border.width: bar.searching ? 1 : 0
        border.color: Theme.alpha(Theme.accent, 0.7)

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    Row {
        id: row

        x: bar.inset
        y: bar.inset
        height: bar.height - 2 * bar.inset

        Repeater {
            model: bar.chips

            Item {
                id: chip

                required property var modelData
                readonly property bool isSelected: bar.current === modelData.id
                // Colour chips are a dot until selected; then they spell their name like the others.
                readonly property bool isSwatch: modelData.icon === undefined
                readonly property bool spelled: isSelected || !isSwatch
                readonly property bool isEmpty: (bar.counts[modelData.id] ?? 0) === 0
                readonly property color ink: isSelected ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

                width: !spelled ? Theme.px(30) : isSwatch ? Theme.px(84) : content.implicitWidth + Theme.px(26)
                height: row.height
                opacity: isEmpty && !isSelected ? 0.35 : 1

                Behavior on width {
                    NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                }

                Binding {
                    bar.selection: chip
                    when: chip.isSelected
                    restoreMode: Binding.RestoreNone
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: chip.isSwatch
                    width: Theme.px(16)
                    height: width
                    radius: width / 2
                    color: bar.hue(chip.modelData.id)
                    opacity: chip.isSelected ? 0 : 1
                    scale: hover.containsMouse ? 1.25 : 1

                    Behavior on scale {
                        NumberAnimation { duration: Theme.fast }
                    }
                }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: Theme.px(7)
                    opacity: chip.spelled ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.normal }
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !chip.isSwatch
                        text: chip.modelData.icon ?? ""
                        size: 17
                        color: chip.ink
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.label
                        size: 13
                        bold: true
                        color: chip.ink

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
                    onClicked: bar.selected(chip.modelData.id)
                }
            }
        }

        Item {
            id: searchBox

            width: bar.searching ? Theme.px(330) : Theme.px(40)
            height: row.height
            clip: true

            Behavior on width {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }

            Binding {
                bar.selection: searchBox
                when: bar.searching
                restoreMode: Binding.RestoreNone
            }

            MouseArea {
                id: opener

                anchors.fill: parent
                enabled: !bar.searching
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.selected("search")
            }

            Icon {
                id: glass

                x: Theme.px(11)
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.search
                size: 18
                color: bar.searching ? Theme.accent : opener.containsMouse ? Theme.text : Theme.subtext
            }

            TextInput {
                id: input

                anchors.left: glass.right
                anchors.right: action.left
                anchors.leftMargin: Theme.px(9)
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.searching
                clip: true
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                selectByMouse: true
                selectionColor: Theme.alpha(Theme.accent, 0.4)
                selectedTextColor: Theme.text
                onAccepted: bar.searchRequested(text.trim())
            }

            Txt {
                anchors.fill: input
                visible: bar.searching && input.text === "" && input.preeditText === ""
                text: "Search wallpapers online"
                size: 13
                color: Theme.dim
            }

            IconBtn {
                id: action

                anchors.right: parent.right
                anchors.rightMargin: Theme.px(3)
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.searching
                size: 30
                icon: bar.searchRunning ? Icons.stop : Icons.arrowRight
                iconColor: bar.searchRunning ? Theme.red : Theme.subtext
                onClicked: bar.searchRunning ? bar.stopRequested() : bar.searchRequested(input.text.trim())
            }
        }
    }
}
