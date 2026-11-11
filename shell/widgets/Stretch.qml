import QtQuick
import qs.core

// The shell's signature selection highlight: a pill that travels between
// targets by stretching — its leading edge arrives quickly, the trailing edge
// catches up. Bind targetStart/targetEnd to the selected item's extent along
// the axis (x for a row, y when `vertical`); the other axis is yours to set.
Rectangle {
    id: root

    property real targetStart: 0
    property real targetEnd: 0
    property bool vertical: false

    // Animated edges.
    property real a: 0
    property real b: 0
    property bool forward: true
    property bool settled: false

    function retarget() {
        if (!settled) {
            a = targetStart;
            b = targetEnd;
            return;
        }
        forward = targetStart > a || (targetStart === a && targetEnd > b);
        a = targetStart;
        b = targetEnd;
    }

    onTargetStartChanged: retarget()
    onTargetEndChanged: retarget()
    Component.onCompleted: {
        retarget();
        settled = true;
    }

    radius: (vertical ? width : height) / 2
    color: Theme.accent

    Binding { root.x: root.a; root.width: root.b - root.a; when: !root.vertical }
    Binding { root.y: root.a; root.height: root.b - root.a; when: root.vertical }

    Behavior on a {
        enabled: root.settled
        NumberAnimation { duration: root.forward ? 350 : 200; easing.type: Easing.OutExpo }
    }
    Behavior on b {
        enabled: root.settled
        NumberAnimation { duration: root.forward ? 200 : 350; easing.type: Easing.OutExpo }
    }
}
