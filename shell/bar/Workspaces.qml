import QtQuick
import qs.core
import qs.widgets

// Workspace pills. The highlight shows the workspace active on this bar's monitor.
BarGroup {
    id: root

    required property var screen

    readonly property int active: Daemon.hypr.monitorActive[screen.name] ?? Daemon.hypr.active
    readonly property var byId: {
        const map = {};
        for (const w of Daemon.hypr.workspaces)
            map[w.id] = w;
        return map;
    }
    // The configured number of pills, plus any higher workspace that is in use.
    readonly property int count: {
        let n = Daemon.setting("workspaceCount", 8);
        for (const w of Daemon.hypr.workspaces)
            if (w.id > n && w.id <= 20)
                n = w.id;
        return Math.max(n, Math.min(active, 20));
    }
    readonly property real pill: Theme.px(32)
    readonly property real step: pill + Theme.px(6)

    function go(id) {
        if (id >= 1 && id !== active)
            Daemon.send("hypr.workspace", { id: id });
    }

    padding: Theme.px(8)

    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.count * root.step - Theme.px(6)
        implicitHeight: root.pill

        Stretch {
            height: root.pill
            visible: root.active >= 1 && root.active <= root.count
            targetStart: (root.active - 1) * root.step
            targetEnd: targetStart + root.pill
        }

        Repeater {
            model: root.count

            Clickable {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property var info: root.byId[wsId]
                readonly property bool isActive: wsId === root.active
                readonly property bool occupied: !!info && info.windows > 0
                // Showing on another monitor.
                readonly property bool elsewhere: !isActive && !!info && Daemon.hypr.monitorActive[info.monitor] === wsId

                x: index * root.step
                width: root.pill
                height: root.pill
                radius: root.pill / 2
                fill: isActive ? "transparent" : occupied ? Theme.alpha(Theme.surface2, 0.55) : "transparent"
                border.width: elsewhere ? 1 : 0
                border.color: Theme.alpha(Theme.accent, 0.6)
                onClicked: root.go(wsId)
                onWheel: wheel => root.go(root.active + (wheel.angleDelta.y > 0 ? -1 : 1))

                Txt {
                    anchors.centerIn: parent
                    text: ws.wsId
                    size: 13
                    bold: true
                    color: ws.isActive ? Theme.accentText : ws.occupied ? Theme.text : Theme.dim

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }
            }
        }
    }
}
