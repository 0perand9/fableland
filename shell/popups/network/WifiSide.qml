import QtQuick
import qs.core

// Wi-Fi, from the `net` topic.
Side {
    id: root

    readonly property var wifi: Daemon.net.wifi
    readonly property var current: wifi.connected ?? null
    // SSID → "connecting" | "failed" while (and shortly after) a connection attempt.
    readonly property var ops: Daemon.net.ops ?? ({})

    function band(mhz) {
        return mhz >= 5925 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : "2.4 GHz";
    }

    function peerCard(network) {
        const state = network.active ? "" : (ops[network.ssid] ?? "");
        return {
            key: network.ssid,
            kind: "peer",
            icon: Icons.wifiSignal(network.signal),
            title: network.ssid,
            note: network.active ? "Connected" : state === "connecting" ? "Connecting…" : state === "failed" ? "Could not connect"
                : (network.security || "Open") + " · " + band(network.frequency),
            hint: network.active ? "Show details" : network.secure && !network.saved ? "Enter password" : "Connect",
            tone: network.active ? "linked" : state === "connecting" ? "busy" : state === "failed" ? "failed" : network.saved ? "known" : "",
            linked: network.active,
            known: network.saved,
            locked: network.secure && !network.saved,
            // In use first, then saved ones, then by strength in four coarse steps:
            // exact signal order would reshuffle the orbit with every scan.
            rank: (network.active ? 0 : network.saved ? 4 : 8) + 3 - Math.min(3, Math.floor(network.signal / 25))
        };
    }

    function setPowered(on) {
        Daemon.send("net.wifiSetEnabled", { enabled: on });
    }

    function connect(ssid, password) {
        Daemon.send("net.wifiConnect", password ? { ssid: ssid, password: password } : { ssid: ssid });
    }

    // There is only ever one Wi-Fi link, so the key is not needed.
    function disconnect(ssid) {
        Daemon.send("net.wifiDisconnect");
    }

    function forget(ssid) {
        Daemon.send("net.wifiForget", { ssid: ssid });
    }

    function rescan() {
        Daemon.send("net.wifiScan");
    }

    key: "wifi"
    title: "Wi-Fi"
    icon: Icons.wifi
    hue: Theme.blue
    present: !!wifi.present
    powered: !!wifi.enabled
    offTitle: "Wi-Fi is off"
    canRescan: true
    peersTitle: "Networks"
    status: !powered ? "Off"
        : current ? (current.ready ? "Connected to " : "Connecting to ") + current.ssid
        : peers.length === 0 ? "Looking for networks…"
        : peers.length === 1 ? "1 network in range" : peers.length + " networks in range"

    links: !current ? [] : [{
            key: current.ssid,
            title: current.ssid,
            icon: Icons.wifiSignal(current.signal),
            level: current.signal / 100,
            state: current.ready ? "" : "connecting",
            facts: [
                { key: "fact:signal", kind: "fact", icon: Icons.wifiSignal(current.signal), title: current.signal + "%", note: "Signal" },
                { key: "fact:security", kind: "fact", icon: current.security ? Icons.lock : Icons.unlock, title: current.security || "Open", note: "Security" },
                { key: "fact:ip", kind: "fact", icon: Icons.ip, title: current.ip || "No address", note: "IP address", copy: !!current.ip },
                { key: "fact:frequency", kind: "fact", icon: Icons.frequency, title: current.frequency + " MHz", note: band(current.frequency) + " band" }
            ]
        }]

    peers: (wifi.networks ?? []).map(peerCard).sort((a, b) => a.rank - b.rank || a.title.localeCompare(b.title))
}
