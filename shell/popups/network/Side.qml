import QtQuick
import qs.core

// One way of being connected — Wi-Fi, Bluetooth or Ethernet — in the shape the
// network popup draws: what sits in the hub (`links`), and what circles around
// it (a link's `facts`, or the `peers` in reach). WifiSide, BluetoothSide and
// EthernetSide translate the daemon's topics into this, and add the actions
// their medium has — setPowered(on), connect(key, password), disconnect(key),
// forget(key), rescan() — where `key` names a peer or a link.
QtObject {
    // "wifi", "bt" or "eth" — also the popup argument that selects this side.
    property string key: ""
    property string title: ""
    property string icon: ""
    property color hue: Theme.accent

    // The adapter exists.
    property bool present: false
    // The radio is on. Ethernet has no radio: there it means the cable is in use.
    property bool powered: false
    // One line for the header: "Connected to home", "5 networks in range", …
    property string status: ""
    // What the hub says while powered without a link.
    property string idleText: "Not connected"
    // What the power button says while the side is off.
    property string offTitle: ""
    property string offHint: "Click to turn on"
    // Looking for peers right now.
    property bool searching: false
    property bool canRescan: false
    // Name of the peer list ("Networks", "Devices"); empty for a side without one.
    property string peersTitle: ""

    // Connections in use, one hub each:
    //   { key, title, icon, level, state, facts }
    // `level` (0 … 1) is how full the hub is drawn (signal, battery); `state` is
    // "", "connecting" or "disconnecting"; `facts` are cards like the peers:
    //   { key, kind: "fact", icon, title, note, copy }
    property var links: []
    // Everything in reach, as cards:
    //   { key, kind: "peer", icon, title, note, hint, tone, linked, known, locked }
    // `tone` is "", "known", "linked", "busy" or "failed" (see Satellite); `known`
    // peers can be forgotten; `locked` ones need a password to connect.
    property var peers: []
}
