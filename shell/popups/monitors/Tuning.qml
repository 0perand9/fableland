import QtQuick
import qs.core
import qs.widgets
import "layout.js" as Layout

// What can be set on a monitor besides its resolution: refresh rate, scale and
// rotation. It only asks for changes — the page owns the layout being edited.
Column {
    id: root

    // The monitor as it stands in the draft, or null.
    property var monitor: null
    // The refresh rates its resolution offers, highest first.
    property var rates: []
    // The section the arrow keys act on, numbered as in Monitors.qml.
    property int section: 0

    readonly property int rateAt: monitor ? Layout.nearestRate(rates, monitor.refreshRate) : -1
    readonly property int turn: monitor ? monitor.transform % 4 : 0
    readonly property bool flipped: monitor ? monitor.transform >= 4 : false

    // Fields of the monitor to change, asked for in `section`.
    signal edited(int section, var changes)

    function setRate(at) {
        if (at >= 0 && at < rates.length)
            root.edited(1, { refreshRate: rates[at] });
    }

    // Hyprland takes only scales that divide the mode evenly: go to the one nearest to `wanted`.
    function setScale(wanted) {
        root.edited(2, { scale: Layout.cleanScale(monitor.width, monitor.height, wanted) });
    }

    // The next such scale up (`way` 1) or down (-1).
    function stepScale(way) {
        root.edited(2, { scale: Layout.nextScale(monitor.width, monitor.height, monitor.scale, way) });
    }

    function setTurn(quarters) {
        root.edited(3, { transform: (flipped ? 4 : 0) + (quarters + 4) % 4 });
    }

    spacing: Theme.px(24)

    Section {
        width: parent.width
        title: "Refresh rate"
        value: root.rateAt >= 0 ? root.rates[root.rateAt] + " Hz" : ""
        current: root.section === 1

        Tabs {
            width: parent.width
            implicitHeight: Theme.px(34)
            size: 12
            // Two decimals tell 60 from 59.94; trailing zeros say nothing.
            model: root.rates.map(rate => String(Math.round(rate * 100) / 100))
            current: root.rateAt
            onSelected: index => root.setRate(index)
        }
    }

    Section {
        width: parent.width
        title: "Scale"
        value: {
            const m = root.monitor;
            return m ? Math.round(m.scale * 100) / 100 + "× · looks like " + Math.round(m.width / m.scale) + " × " + Math.round(m.height / m.scale) : "";
        }
        current: root.section === 2

        Slide {
            width: parent.width
            from: Layout.MIN_SCALE
            to: Layout.MAX_SCALE
            value: root.monitor?.scale ?? 1
            interactive: root.monitor !== null
            onMoved: value => root.setScale(value)
        }
    }

    Section {
        width: parent.width
        title: "Rotation"
        value: root.turn * 90 + "°" + (root.flipped ? " · mirrored" : "")
        current: root.section === 3

        Tabs {
            id: turns

            width: parent.width - mirror.width - Theme.px(14)
            implicitHeight: Theme.px(34)
            size: 12
            model: ["0°", "90°", "180°", "270°"]
            current: root.turn
            onSelected: index => root.setTurn(index)
        }

        Row {
            id: mirror

            anchors.right: parent.right
            anchors.verticalCenter: turns.verticalCenter
            spacing: Theme.px(8)

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Mirror"
                size: 12
                color: Theme.subtext
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.flipped
                interactive: root.monitor !== null
                onToggled: checked => root.edited(3, { transform: root.turn + (checked ? 4 : 0) })
            }
        }
    }
}
