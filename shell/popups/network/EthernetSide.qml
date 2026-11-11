import QtQuick
import qs.core

// The wired connection, from the `net` topic. It has no peers: the hub and
// its facts are all there is.
Side {
    id: root

    readonly property var eth: Daemon.net.ethernet

    // 1000 → "1 Gb/s", 100 → "100 Mb/s"
    function speed(mbps) {
        if (!mbps)
            return "Unknown";
        return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s";
    }

    // "Powering" the wired side connects or disconnects the cable.
    function setPowered(on) {
        Daemon.send("net.ethernetSet", { connected: on });
    }

    function disconnect(device) {
        setPowered(false);
    }

    key: "eth"
    title: "Ethernet"
    icon: Icons.ethernet
    hue: Theme.blue
    present: !!eth.present
    powered: !!eth.connected || !!eth.busy
    offTitle: "Not connected"
    offHint: "Click to connect"
    idleText: "Connecting…"
    status: eth.connected ? "Connected · " + speed(eth.speed) : eth.busy ? "Connecting…" : "Disconnected"

    links: !eth.connected ? [] : [{
            key: eth.device,
            title: eth.name || "Wired",
            icon: Icons.ethernet,
            level: 1,
            state: "",
            facts: [
                { key: "fact:ip", kind: "fact", icon: Icons.ip, title: eth.ip || "No address", note: "IP address", copy: !!eth.ip },
                { key: "fact:speed", kind: "fact", icon: Icons.speedometer, title: speed(eth.speed), note: "Link speed" },
                { key: "fact:mac", kind: "fact", icon: Icons.chip, title: eth.mac ?? "", note: "MAC address", copy: !!eth.mac },
                { key: "fact:device", kind: "fact", icon: Icons.lan, title: eth.device ?? "", note: "Interface" }
            ]
        }]
}
