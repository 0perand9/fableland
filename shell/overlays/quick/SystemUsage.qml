import QtQuick
import qs.core
import qs.widgets

// System usage: processor, temperature, memory, disk, graphics card and
// network. The daemon samples these only while this is open (every 2 s); the
// graphs show the time since then, two minutes at most.
Item {
    id: usage

    readonly property var sys: Daemon.sys
    readonly property var gpu: sys?.gpu ?? null
    readonly property var net: Daemon.net
    readonly property var link: net.primary === "ethernet" ? net.ethernet : net.primary === "wifi" ? net.wifi.connected : null

    // Two minutes of samples: as many as a graph is wide (Sparkline.capacity).
    readonly property int depth: 60
    // Recent samples of each reading, oldest first.
    property var past: ({ cpu: [], temp: [], ram: [], gpu: [], rx: [], tx: [] })
    // Both network graphs share one scale: the busiest moment on record, and
    // never less than 100 KB/s so that idle chatter stays flat.
    readonly property real netPeak: Math.max(102400, ...past.rx, ...past.tx)

    // Usage readings wear the accent; only temperature and network have hues of their own.
    readonly property color downHue: Theme.blue
    readonly property color upHue: Theme.pink

    readonly property real gap: Theme.px(10)
    readonly property real half: (layout.width - gap) / 2

    function record(sample) {
        if (!sample)
            return;
        const next = {};
        const keep = (key, value) => next[key] = past[key].concat([value ?? 0]).slice(-depth);
        keep("cpu", sample.cpu);
        keep("temp", sample.temp);
        keep("ram", sample.ram);
        keep("gpu", sample.gpu?.usage);
        keep("rx", sample.rx);
        keep("tx", sample.tx);
        past = next;
    }

    function percent(value) {
        return value === undefined || value === null ? "–" : Math.round(value) + "%";
    }

    function degrees(value) {
        return value === undefined || value === null ? "–" : Math.round(value) + "°C";
    }

    // "12.3 / 126 GiB"
    function share(used, total) {
        const figure = n => n >= 100 ? Math.round(n) : n.toFixed(1);
        return figure(used) + " / " + figure(total) + " GiB";
    }

    implicitWidth: Theme.px(400)
    implicitHeight: layout.implicitHeight + 2 * layout.y

    Want {
        topic: "sys"
    }

    Connections {
        target: Daemon

        function onSysChanged() {
            usage.record(Daemon.sys);
        }
    }

    component Rate: Row {
        property string icon: ""
        property color hue: Theme.blue
        property real bytes: 0

        spacing: Theme.px(6)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            size: 14
            color: parent.hue
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(84)
            horizontalAlignment: Text.AlignRight
            text: Fmt.bytes(parent.bytes) + "/s"
            size: 13
            bold: true
        }
    }

    Column {
        id: layout

        x: Theme.px(14)
        y: Theme.px(14)
        width: parent.width - 2 * x
        spacing: usage.gap

        Row {
            spacing: usage.gap

            UsageTile {
                width: usage.half
                icon: Icons.cpu
                title: "Processor"
                value: usage.percent(usage.sys?.cpu)
                level: (usage.sys?.cpu ?? 0) / 100
                series: [{ values: usage.past.cpu, color: hue }]
            }

            UsageTile {
                // Not every machine has a sensor the daemon can read.
                readonly property bool sensed: (usage.sys?.temp ?? null) !== null

                width: usage.half
                icon: Icons.thermometer
                title: "Temperature"
                value: usage.degrees(usage.sys?.temp)
                detail: usage.sys && !sensed ? "No sensor" : ""
                level: (usage.sys?.temp ?? 0) / 100
                hue: Theme.peach
                alarm: 0.9
                series: sensed ? [{ values: usage.past.temp, color: hue }] : []
            }
        }

        Row {
            spacing: usage.gap

            UsageTile {
                width: usage.half
                icon: Icons.memory
                title: "Memory"
                value: usage.percent(usage.sys?.ram)
                detail: usage.sys ? usage.share(usage.sys.ramUsed, usage.sys.ramTotal) : ""
                level: (usage.sys?.ram ?? 0) / 100
                alarm: 0.9
                series: [{ values: usage.past.ram, color: hue }]
            }

            UsageTile {
                id: disk

                readonly property var space: usage.sys?.disk ?? null

                width: usage.half
                icon: Icons.disk
                title: "Disk"
                value: usage.percent(space?.percent)
                detail: space ? Fmt.bytes(space.total - space.used) + " free" : ""
                level: (space?.percent ?? 0) / 100
                alarm: 0.95
            }
        }

        UsageTile {
            visible: usage.gpu !== null
            width: parent.width
            icon: Icons.gpu
            title: usage.gpu?.name || "Graphics"
            value: usage.percent(usage.gpu?.usage)
            detail: usage.gpu ? usage.degrees(usage.gpu.temp) + "  ·  " + usage.share(usage.gpu.memUsed / 1024, usage.gpu.memTotal / 1024) : ""
            level: (usage.gpu?.usage ?? 0) / 100
            series: [{ values: usage.past.gpu, color: hue }]
        }

        UsageTile {
            width: parent.width
            icon: usage.net.primary === "wifi" ? Icons.wifi : usage.link ? Icons.ethernet : Icons.lanOff
            title: "Network"
            value: usage.net.primary === "wifi" ? (usage.link?.ssid ?? "Wi-Fi") : usage.link ? "Ethernet" : "Offline"
            detail: usage.link?.ip ?? ""
            level: -1
            hue: Theme.blue
            series: [{ values: usage.past.rx, color: usage.downHue }, { values: usage.past.tx, color: usage.upHue }]
            ceiling: usage.netPeak

            Column {
                spacing: Theme.px(4)

                Rate {
                    icon: Icons.arrowDown
                    hue: usage.downHue
                    bytes: usage.sys?.rx ?? 0
                }

                Rate {
                    icon: Icons.arrowUp
                    hue: usage.upHue
                    bytes: usage.sys?.tx ?? 0
                }
            }
        }
    }
}
