import QtQuick
import qs.core
import qs.widgets

// One equalizer band: a vertical slider around 0 dB that fills from the middle,
// in whole decibels. Like Slide, `value` is the truth from outside; while the
// user drags (and for a moment after) the band shows the pointer instead.
Item {
    id: root

    property real value: 0                      // dB
    property real range: 12                     // the band spans −range … +range
    property string label: ""                   // its frequency, shown below
    property color accentColor: Theme.accent
    // 0 … 1: lights the knob up, for the sweep that runs when settings take effect.
    property real flash: 0

    readonly property bool held: mouse.pressed || settle.running
    readonly property real shown: held ? pointerValue : value
    property real pointerValue: 0
    // The knob glides when the truth changes (a preset) and sticks to the pointer when dragged.
    property real level: shown
    // Vertical positions of 0 dB and of the knob's centre; the curve across the bands uses them.
    readonly property real zeroY: track.y + track.height / 2
    readonly property real knobY: track.y + track.height * (range - level) / (2 * range)

    signal moved(real value)

    function clampValue(v) {
        return Math.round(Math.max(-range, Math.min(range, v)));
    }

    function pick(v) {
        pointerValue = v;
        moved(v);
    }

    Behavior on level {
        enabled: !root.held
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: (root.shown > 0 ? "+" : "") + Math.round(root.shown)
        size: 10
        color: mouse.containsMouse || root.held ? Theme.text : Math.round(root.shown) === 0 ? Theme.dim : Theme.subtext
    }

    Rectangle {
        id: track

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(24)
        width: Theme.px(8)
        height: root.height - 2 * y
        radius: width / 2
        color: Theme.alpha(Theme.surface2, 0.55)
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(root.zeroY, root.knobY)
        width: track.width
        height: Math.abs(root.knobY - root.zeroY)
        radius: width / 2
        color: root.accentColor

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    Rectangle {
        id: knob

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.knobY - height / 2
        width: Theme.px(16)
        height: width
        radius: width / 2
        color: Theme.text
        scale: (mouse.pressed ? 1.25 : mouse.containsMouse ? 1.1 : 1) + 0.3 * root.flash

        Behavior on scale {
            enabled: root.flash === 0
            NumberAnimation { duration: Theme.fast }
        }

        Rectangle {
            anchors.centerIn: parent
            z: -1
            width: parent.width * (1 + 1.6 * root.flash)
            height: width
            radius: width / 2
            color: Theme.alpha(root.accentColor, 0.5 * root.flash)
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        size: 10
        color: Theme.dim
    }

    Timer {
        id: settle

        interval: 350
    }

    MouseArea {
        id: mouse

        function valueAt(y) {
            return root.clampValue(root.range - 2 * root.range * (y - track.y) / Math.max(1, track.height));
        }

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.pick(valueAt(mouse.y))
        onPositionChanged: mouse => {
            if (pressed && valueAt(mouse.y) !== root.pointerValue)
                root.pick(valueAt(mouse.y));
        }
        onReleased: settle.restart()
        onWheel: wheel => {
            root.pick(root.clampValue(root.shown + (wheel.angleDelta.y > 0 ? 1 : -1)));
            settle.restart();
        }
    }
}
