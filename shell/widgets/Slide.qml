import QtQuick
import qs.core

// A horizontal slider. `value` is the truth from outside; while the user drags
// (and for a moment after, until the truth catches up) the slider shows the
// pointer instead. React to onMoved to apply the change.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    // Change per wheel notch.
    property real step: (to - from) / 20
    property color accentColor: Theme.accent
    property color trackColor: Theme.alpha(Theme.surface2, 0.55)
    property bool interactive: true
    property real thickness: 6

    readonly property bool dragging: mouse.pressed
    readonly property bool held: mouse.pressed || settle.running
    readonly property real shown: held ? pointerValue : value
    readonly property real fraction: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0
    property real pointerValue: 0

    signal moved(real value)
    signal released(real value)

    function clampValue(v) {
        return Math.max(from, Math.min(to, v));
    }

    implicitWidth: Theme.px(200)
    implicitHeight: Theme.px(22)
    opacity: interactive ? 1 : 0.45

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.px(root.thickness)
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: Math.max(height, parent.width * root.fraction)
            height: parent.height
            radius: height / 2
            color: root.accentColor
            visible: root.fraction > 0

            Behavior on width {
                enabled: !root.held
                NumberAnimation { duration: Theme.fast }
            }
        }
    }

    Rectangle {
        readonly property real size: Theme.px(root.thickness + 8)

        x: (root.width - size) * root.fraction
        anchors.verticalCenter: parent.verticalCenter
        width: size
        height: size
        radius: size / 2
        color: Theme.text
        scale: mouse.pressed ? 1.15 : mouse.containsMouse ? 1 : 0
        visible: root.interactive

        Behavior on scale {
            NumberAnimation { duration: Theme.fast }
        }
        Behavior on x {
            enabled: !root.held
            NumberAnimation { duration: Theme.fast }
        }
    }

    Timer {
        id: settle

        interval: 350
    }

    MouseArea {
        id: mouse

        function valueAt(x) {
            return root.clampValue(root.from + (root.to - root.from) * x / Math.max(1, width));
        }

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.pointerValue = valueAt(mouse.x);
            root.moved(root.pointerValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.pointerValue = valueAt(mouse.x);
            root.moved(root.pointerValue);
        }
        onReleased: {
            settle.restart();
            root.released(root.pointerValue);
        }
        onWheel: wheel => {
            const next = root.clampValue(root.shown + (wheel.angleDelta.y > 0 ? root.step : -root.step));
            root.pointerValue = next;
            settle.restart();
            root.moved(next);
        }
    }
}
