import QtQuick
import qs.core
import qs.widgets
import qs.popups.control

// The control centre: the notification history on the left; on the right who
// is logged in, batteries, power profile, brightness and volume, and the
// session actions. Parts the machine does not have (a battery, a backlight,
// power profiles) are left out, and the popup is as tall as the rest needs.
// Without the notifications feature the right side is all of it.
//
// Keys: Up / Down / Page Up / Page Down scroll the notifications.
PopupPage {
    id: page

    readonly property var power: Daemon.power
    readonly property var sink: Daemon.audio.sink
    readonly property int margin: Theme.px(24)
    // Design units: the column of controls, and the notification history with the divider beside it.
    readonly property int controlsWidth: 391
    readonly property int historyWidth: 381
    // The profiles power-profiles-daemon knows, with how to show them.
    readonly property var profileLooks: ({
            "power-saver": { label: "Saver", icon: Icons.leaf, hue: Theme.green },
            "balanced": { label: "Balanced", icon: Icons.balance, hue: Theme.accent },
            "performance": { label: "Performance", icon: Icons.speedometer, hue: Theme.peach }
        })

    function profileLook(profile) {
        return profileLooks[profile] ?? { label: Fmt.capitalize(profile ?? ""), icon: Icons.bolt, hue: Theme.accent };
    }

    implicitWidth: Theme.px(controlsWidth + (history.visible ? historyWidth : 0)) + 2 * margin
    // Never shorter than a useful notification list needs; the user card takes up the slack.
    implicitHeight: Math.max(history.visible ? Theme.px(590) : 0, user.implicitHeight + controls.spacing + controls.implicitHeight + 2 * margin)
    placement: "top-right"

    Keys.onUpPressed: notifications.scrollBy(-Theme.px(80))
    Keys.onDownPressed: notifications.scrollBy(Theme.px(80))
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            notifications.scrollBy((event.key === Qt.Key_PageUp ? -0.8 : 0.8) * notifications.height);
            event.accepted = true;
        }
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.yellow, Theme.accent, Theme.green]
    }

    Item {
        id: history

        visible: Daemon.has("notifications")
        x: page.margin
        y: page.margin
        width: visible ? Theme.px(page.historyWidth) : 0
        height: parent.height - 2 * page.margin

        NotificationCenter {
            id: notifications

            width: Theme.px(340)
            height: parent.height
        }

        Rectangle {
            anchors.left: notifications.right
            anchors.leftMargin: Theme.px(20)
            width: 1
            height: parent.height
            color: Theme.border
        }
    }

    UserCard {
        id: user

        anchors.left: history.right
        anchors.right: parent.right
        anchors.rightMargin: page.margin
        anchors.top: parent.top
        anchors.topMargin: page.margin
        anchors.bottom: controls.top
        anchors.bottomMargin: controls.spacing
    }

    Column {
        id: controls

        anchors.left: user.left
        anchors.right: user.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: page.margin
        spacing: Theme.px(14)

        PowerCard {
            width: parent.width
            visible: hasContent
        }

        Tabs {
            readonly property var look: page.profileLook(page.power.profile)

            width: parent.width
            visible: page.power.profiles.length > 0
            model: page.power.profiles.map(profile => page.profileLook(profile))
            current: page.power.profiles.indexOf(page.power.profile)
            accentColor: look.hue
            onSelected: index => Daemon.send("power.setProfile", { profile: page.power.profiles[index] })
        }

        Card {
            width: parent.width
            implicitHeight: levels.implicitHeight + 2 * Theme.px(14)

            Column {
                id: levels

                x: Theme.px(14)
                y: Theme.px(14)
                width: parent.width - 2 * x
                spacing: Theme.px(12)

                LevelRow {
                    width: parent.width
                    visible: page.power.brightness.present
                    icon: Icons.brightnessLevel(page.power.brightness.percent)
                    hue: Theme.yellow
                    value: page.power.brightness.percent
                    onMoved: value => Daemon.stream("brightness", "power.setBrightness", { value: Math.round(value), quiet: true })
                }

                LevelRow {
                    width: parent.width
                    icon: Icons.volume(page.sink?.volume ?? 0, page.sink?.muted ?? false)
                    hue: Theme.peach
                    value: page.sink?.volume ?? 0
                    muted: page.sink?.muted ?? false
                    toggles: true
                    enabled: !!page.sink
                    opacity: enabled ? 1 : 0.45
                    onMoved: value => Daemon.stream("volume-sinkdefault", "audio.setVolume", { kind: "sink", id: "default", value: Math.round(value), quiet: true })
                    onToggled: Daemon.send("audio.toggleMute", { kind: "sink", id: "default" })
                }
            }
        }

        SessionActions {
            width: parent.width
        }
    }
}
