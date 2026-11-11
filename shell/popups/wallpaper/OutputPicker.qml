import QtQuick
import qs.core
import qs.widgets

// Chooses the monitors a wallpaper is applied to. Every monitor takes part
// until the user takes it out; the last one cannot be taken out.
Pill {
    id: root

    readonly property var names: Daemon.monitors.map(monitor => monitor.name)
    // Monitors the user took out. Kept by exclusion so that a monitor plugged in later takes part.
    property var excluded: []
    readonly property var chosen: names.filter(name => excluded.indexOf(name) < 0)
    // The `outputs` parameter of the daemon's wallpaper calls: empty means all of them.
    readonly property var outputs: chosen.length === names.length ? [] : chosen

    function toggle(name) {
        if (excluded.indexOf(name) >= 0)
            excluded = excluded.filter(other => other !== name);
        else if (chosen.length > 1)
            excluded = excluded.concat(name);
    }

    visible: names.length > 1
    implicitWidth: row.width + 2 * inset

    Row {
        id: row

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(34)
            text: Icons.monitors
            size: 18
            color: Theme.subtext
        }

        Repeater {
            model: root.names

            Clickable {
                id: chip

                required property string modelData
                readonly property bool isChosen: root.chosen.indexOf(modelData) >= 0

                width: label.implicitWidth + Theme.px(22)
                height: root.height - 2 * root.inset
                radius: height / 2
                fill: isChosen ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                onClicked: root.toggle(modelData)

                Txt {
                    id: label

                    anchors.centerIn: parent
                    text: chip.modelData
                    size: 12
                    bold: true
                    color: chip.isChosen ? Theme.accent : Theme.dim
                }
            }
        }
    }
}
