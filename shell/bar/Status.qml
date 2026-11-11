import QtQuick
import qs.core
import qs.widgets

// Keyboard layout, network, bluetooth, volume, notifications and power.
BarGroup {
    id: root

    required property var screen

    readonly property var net: Daemon.net
    readonly property var bt: Daemon.bt
    readonly property var sink: Daemon.audio.sink
    readonly property var battery: Daemon.power.battery
    readonly property var recording: Daemon.capture.recording
    readonly property int notifications: Daemon.notif.items.length

    function toggle(popup, arg) {
        Ui.toggle(popup, arg, screen);
    }

    padding: Theme.px(7)
    spacing: Theme.px(5)

    // Screen recording in progress — click to stop.
    StatusPill {
        id: rec

        property real now: Date.now()

        visible: root.recording.active
        icon: Icons.recordDot
        text: Fmt.clock((now - (root.recording.since ?? now)) / 1000)
        hue: Theme.red
        active: true
        onClicked: Daemon.send("capture.stop")

        Timer {
            interval: 1000
            repeat: true
            running: rec.visible
            triggeredOnStart: true
            onTriggered: rec.now = Date.now()
        }

        SequentialAnimation on opacity {
            running: rec.visible
            loops: Animation.Infinite

            NumberAnimation { to: 0.55; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    StatusPill {
        visible: Daemon.hypr.layout !== ""
        icon: Icons.keyboard
        text: Daemon.hypr.layout
        onClicked: Daemon.send("hypr.nextLayout")
    }

    StatusPill {
        readonly property var wifi: root.net.wifi.connected

        icon: root.net.primary === "ethernet" ? Icons.ethernet : root.net.primary === "wifi" ? Icons.wifiSignal(wifi?.signal ?? 0) : Icons.wifiOff
        text: root.net.primary === "wifi" ? (wifi?.ssid ?? "") : root.net.primary === "ethernet" ? "" : "Offline"
        hue: Theme.blue
        active: root.net.primary === "ethernet" || root.net.primary === "wifi"
        onClicked: root.toggle("network", "wifi")
    }

    StatusPill {
        visible: root.bt.present
        icon: !root.bt.powered ? Icons.bluetoothOff : root.bt.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
        text: root.bt.connected.length === 1 ? (root.bt.connected[0].name ?? "") : root.bt.connected.length > 1 ? root.bt.connected.length + " devices" : ""
        hue: Theme.mauve
        active: root.bt.connected.length > 0
        onClicked: root.toggle("network", "bt")
    }

    StatusPill {
        readonly property int volume: Math.round(root.sink?.volume ?? 0)
        readonly property bool muted: root.sink?.muted ?? true

        icon: Icons.volume(volume, muted)
        text: root.sink ? volume + "%" : ""
        hue: Theme.peach
        active: !!root.sink && !muted
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.toggle("volume");
            else
                Daemon.send("audio.toggleMute", { kind: "sink", id: "default" });
        }
        onWheel: wheel => Daemon.send("audio.step", { kind: "sink", delta: wheel.angleDelta.y > 0 ? 5 : -5 })
    }

    StatusPill {
        visible: root.notifications > 0 || Daemon.notif.dnd
        icon: Daemon.notif.dnd ? Icons.bellOff : Icons.bell
        text: root.notifications > 0 ? root.notifications : ""
        hue: Theme.yellow
        active: root.notifications > 0 && !Daemon.notif.dnd
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.toggle("control");
            else
                Daemon.send("notif.setDnd", { on: !Daemon.notif.dnd });
        }
    }

    StatusPill {
        readonly property bool low: root.battery.present && !root.battery.charging && root.battery.percent <= 20

        icon: root.battery.present ? Icons.batteryLevel(root.battery.percent, root.battery.charging) : Icons.power
        text: root.battery.present ? Math.round(root.battery.percent) + "%" : ""
        hue: low ? Theme.red : Theme.green
        active: root.battery.present && (low || root.battery.charging)
        onClicked: root.toggle("control")
    }
}
