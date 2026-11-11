import QtQuick
import qs.core

// Keeps an on-demand daemon topic alive while `active` (and while this object exists).
//   Want { topic: "sys" }                      → Daemon.sys is filled in
//   Want { topic: "wifi"; active: tab === 0 }  → Wi-Fi scanning only while the tab shows
QtObject {
    id: root

    property string topic: ""
    property bool active: true
    property string held: ""

    function sync() {
        const target = active ? topic : "";
        if (target === held)
            return;
        if (held !== "")
            Daemon.unwant(held);
        held = target;
        if (held !== "")
            Daemon.want(held);
    }

    onActiveChanged: sync()
    onTopicChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (held !== "")
            Daemon.unwant(held);
    }
}
