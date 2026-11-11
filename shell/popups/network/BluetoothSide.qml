import QtQuick
import qs.core

// Bluetooth, from the `bt` topic.
Side {
    id: root

    readonly property var bt: Daemon.bt
    // MAC → "connecting" | "disconnecting" | "failed".
    readonly property var ops: bt.ops ?? ({})

    function known(value) {
        return value !== null && value !== undefined;
    }

    function deviceIcon(device) {
        return Icons.device(device.kind, Icons.bluetooth);
    }

    function peerCard(device, linked) {
        const state = ops[device.mac] ?? "";
        const battery = known(device.battery) ? " · " + Math.round(device.battery) + "%" : "";
        return {
            key: device.mac,
            kind: "peer",
            icon: deviceIcon(device),
            title: device.name,
            note: state === "connecting" ? "Connecting…" : state === "disconnecting" ? "Disconnecting…" : state === "failed" ? "Could not connect"
                : linked ? "Connected" + battery : device.paired ? "Paired" : "New device",
            hint: linked ? "Show details" : device.paired ? "Connect" : "Pair and connect",
            tone: state === "failed" ? "failed" : state !== "" ? "busy" : linked ? "linked" : device.paired ? "known" : "",
            linked: linked,
            known: !!device.paired,
            locked: false
        };
    }

    function linkFacts(device) {
        const facts = [];
        if (known(device.battery))
            facts.push({ key: "fact:battery", kind: "fact", icon: Icons.batteryLevel(device.battery, false), title: Math.round(device.battery) + "%", note: "Battery" });
        facts.push({ key: "fact:kind", kind: "fact", icon: deviceIcon(device), title: device.kind === "generic" ? "Device" : Fmt.capitalize(device.kind), note: device.trusted ? "Trusted" : "Type" });
        if (known(device.rssi))
            facts.push({ key: "fact:rssi", kind: "fact", icon: Icons.frequency, title: device.rssi + " dBm", note: "Signal" });
        facts.push({ key: "fact:mac", kind: "fact", icon: Icons.chip, title: device.mac, note: "Address", copy: true });
        return facts;
    }

    function setPowered(on) {
        Daemon.send("bt.setPowered", { on: on });
    }

    // Pairs and trusts first when the device is new.
    function connect(mac) {
        Daemon.send("bt.connect", { mac: mac });
    }

    function disconnect(mac) {
        Daemon.send("bt.disconnect", { mac: mac });
    }

    function forget(mac) {
        Daemon.send("bt.remove", { mac: mac });
    }

    key: "bt"
    title: "Bluetooth"
    icon: Icons.bluetooth
    hue: Theme.mauve
    present: !!bt.present
    powered: !!bt.powered
    offTitle: "Bluetooth is off"
    searching: powered && !!bt.discovering
    idleText: searching ? "Searching…" : "Not connected"
    peersTitle: "Devices"
    status: !powered ? "Off"
        : links.length === 1 ? "Connected to " + links[0].title
        : links.length > 1 ? links.length + " devices connected"
        : searching ? "Searching for devices…" : "Not connected"

    links: bt.connected.map(device => ({
                key: device.mac,
                title: device.name,
                icon: deviceIcon(device),
                // Without a battery reading the hub is simply full.
                level: known(device.battery) ? device.battery / 100 : 1,
                state: ops[device.mac] === "disconnecting" ? "disconnecting" : "",
                facts: linkFacts(device)
            }))

    // Connected devices first, then paired ones; by name within each, so that
    // changing signal strengths do not reshuffle the orbit.
    peers: bt.connected.map(device => peerCard(device, true)).concat(
        bt.devices.map(device => peerCard(device, false)).sort((a, b) => (b.known - a.known) || a.title.localeCompare(b.title)))
}
