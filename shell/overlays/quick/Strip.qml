import QtQuick
import qs.core
import qs.widgets

// The strip of action buttons, then the pin. It runs along the edge the panel
// is docked to; the stretchy highlight marks the module that is open.
Item {
    id: strip

    required property var dock
    property bool vertical: true
    property bool moduleOpen: false

    readonly property real button: Theme.px(40)
    readonly property real spacing: Theme.px(6)
    // Its extent along the edge.
    readonly property real length: (vertical ? buttons.height : buttons.width) + Theme.px(16)
    readonly property bool timing: Daemon.timers.timer.running || Daemon.timers.stopwatch.running || Daemon.timers.pomodoro.running

    function trigger(action) {
        if (action.view)
            dock.toggle(action.id);
        else if (action.id === "draw")
            dock.draw();
    }

    // The wheel flips through the modules: one per notch, with a touchpad's small steps adding up to notches.
    MouseArea {
        property real travel: 0

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            travel += wheel.angleDelta.y;
            if (Math.abs(travel) < 120)
                return;
            strip.dock.cycle(travel < 0 ? 1 : -1);
            travel = 0;
        }
    }

    Stretch {
        readonly property int index: strip.dock.actions.findIndex(action => action.id === strip.dock.module)

        // The Stretch moves along the strip; across it, it covers the button.
        x: buttons.x
        y: buttons.y
        width: strip.button
        height: strip.button
        vertical: strip.vertical
        targetStart: (strip.vertical ? buttons.y : buttons.x) + index * (strip.button + strip.spacing)
        targetEnd: targetStart + strip.button
        opacity: strip.moduleOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }
    }

    Grid {
        id: buttons

        anchors.centerIn: parent
        // One column down a side edge, one row along the bottom.
        columns: strip.vertical ? 1 : strip.dock.actions.length + 2
        spacing: strip.spacing
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: strip.dock.actions

            IconBtn {
                id: actionButton

                required property var modelData
                readonly property bool showing: strip.moduleOpen && modelData.id === strip.dock.module

                icon: modelData.icon
                size: 40
                iconSize: 21
                iconColor: showing ? Theme.accentText : hovered ? Theme.text : Theme.subtext
                active: modelData.id === "draw" && strip.dock.drawing
                onClicked: strip.trigger(modelData)

                // A timer is running.
                Rectangle {
                    visible: actionButton.modelData.id === "timers" && strip.timing && !actionButton.showing
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(7)
                    width: Theme.px(7)
                    height: width
                    radius: width / 2
                    color: Theme.accent
                }
            }
        }

        Rectangle {
            width: strip.vertical ? Theme.px(20) : 1
            height: strip.vertical ? 1 : Theme.px(20)
            color: Theme.border
        }

        IconBtn {
            icon: strip.dock.pinned ? Icons.pin : Icons.pinOutline
            size: 40
            iconSize: 19
            iconColor: strip.dock.pinned ? Theme.accent : hovered ? Theme.text : Theme.dim
            onClicked: strip.dock.pinned = !strip.dock.pinned
        }
    }
}
