import QtQuick
import qs.core
import qs.widgets

// One line of the keybind cheat-sheet: the key caps, what the bind does, and
// (for binds written in Lua) the call behind it.
Item {
    id: row

    // An entry made by binds.js: { mods, key, title, detail, repeat, locked, mouse }.
    required property var entry
    // Where the description column starts, so that every row lines up.
    property int keysWidth: Theme.px(250)

    readonly property var flags: {
        const out = [];
        if (entry.repeat)
            out.push("repeats");
        if (entry.locked)
            out.push("works locked");
        if (entry.mouse)
            out.push("hold & drag");
        return out;
    }

    implicitHeight: Theme.px(40)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.surface0, hover.hovered ? 0.7 : 0)

        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }
    }

    HoverHandler {
        id: hover
    }

    Row {
        x: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        Repeater {
            model: row.entry.mods

            KeyCap {
                required property string modelData

                label: modelData
            }
        }

        KeyCap {
            label: row.entry.key
            primary: true
        }
    }

    Txt {
        id: title

        x: row.keysWidth
        width: Math.min(implicitWidth, tail.x - x - Theme.px(16))
        anchors.verticalCenter: parent.verticalCenter
        text: row.entry.title
        size: 13
    }

    Row {
        id: tail

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(8)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            // The description keeps at least a third of the row.
            width: Math.min(implicitWidth, Math.max(0, row.width * 0.62 - row.keysWidth))
            text: row.entry.detail
            size: 11
            color: Theme.dim
        }

        Repeater {
            model: row.flags

            Rectangle {
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                width: flag.implicitWidth + Theme.px(12)
                height: Theme.px(20)
                radius: height / 2
                color: Theme.alpha(Theme.surface2, 0.6)

                Txt {
                    id: flag

                    anchors.centerIn: parent
                    text: parent.modelData
                    size: 10
                    color: Theme.subtext
                }
            }
        }
    }
}
