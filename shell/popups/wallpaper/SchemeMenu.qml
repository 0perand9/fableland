import QtQuick
import qs.core
import qs.widgets

// How the wallpaper becomes the shell's palette: dark or light, and which
// matugen scheme. Shows the daemon's settings and changes them; the daemon
// regenerates the palette when they change.
Rectangle {
    id: menu

    property bool open: false

    readonly property string scheme: Daemon.setting("wallpaper.scheme", "scheme-vibrant")
    readonly property bool light: Daemon.setting("wallpaper.mode", "dark") === "light"
    readonly property var schemes: [
        { id: "scheme-vibrant", label: "Vibrant" },
        { id: "scheme-tonal-spot", label: "Tonal spot" },
        { id: "scheme-expressive", label: "Expressive" },
        { id: "scheme-fidelity", label: "Fidelity" },
        { id: "scheme-content", label: "Content" },
        { id: "scheme-fruit-salad", label: "Fruit salad" },
        { id: "scheme-rainbow", label: "Rainbow" },
        { id: "scheme-neutral", label: "Neutral" },
        { id: "scheme-monochrome", label: "Monochrome" }
    ]

    implicitWidth: Theme.px(230)
    implicitHeight: content.height + 2 * content.y
    radius: Theme.radius
    color: Theme.mantle
    border.width: 1
    border.color: Theme.border
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.94
    transformOrigin: Item.TopRight

    Behavior on opacity {
        NumberAnimation { duration: Theme.fast }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
    }

    // Clicks on the menu's own surface must not fall through to what is under it.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content

        x: Theme.px(10)
        y: Theme.px(10)
        width: parent.width - 2 * x
        spacing: Theme.px(8)

        Tabs {
            width: parent.width
            implicitHeight: Theme.px(36)
            model: [{ label: "Dark", icon: Icons.moon }, { label: "Light", icon: Icons.sun }]
            current: menu.light ? 1 : 0
            onSelected: index => Daemon.setSetting("wallpaper.mode", index === 1 ? "light" : "dark")
        }

        Column {
            width: parent.width
            spacing: Theme.px(2)

            Repeater {
                model: menu.schemes

                Clickable {
                    id: row

                    required property var modelData
                    readonly property bool isCurrent: menu.scheme === modelData.id

                    width: parent.width
                    height: Theme.px(32)
                    fill: isCurrent ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                    onClicked: Daemon.setSetting("wallpaper.scheme", modelData.id)

                    Txt {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        size: 13
                        color: row.isCurrent ? Theme.accent : Theme.text
                    }

                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.isCurrent
                        text: Icons.check
                        size: 16
                        color: Theme.accent
                    }
                }
            }
        }
    }
}
