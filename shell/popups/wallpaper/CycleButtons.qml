import QtQuick
import qs.core
import qs.widgets

// Change the wallpaper without choosing one — the previous, a random or the
// next one of the library — and open the folder they live in.
Pill {
    implicitWidth: row.width + 2 * inset

    Row {
        id: row

        anchors.centerIn: parent

        Repeater {
            model: [
                { icon: Icons.previous, direction: "prev" },
                { icon: Icons.shuffle, direction: "random" },
                { icon: Icons.next, direction: "next" }
            ]

            IconBtn {
                required property var modelData

                icon: modelData.icon
                size: 36
                iconColor: Theme.subtext
                onClicked: Daemon.send("wallpaper.cycle", { direction: modelData.direction })
            }
        }

        IconBtn {
            icon: Icons.folderOpen
            size: 36
            iconColor: Theme.subtext
            onClicked: Daemon.send("misc.open", { target: Daemon.wallpaper.dir })
        }
    }
}
