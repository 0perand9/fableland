import QtQuick
import qs.core

// "Something is happening."
Ring {
    id: root

    property bool running: visible

    implicitWidth: Theme.px(22)
    implicitHeight: Theme.px(22)
    thickness: 3
    value: 0.3
    trackColor: Theme.alpha(color, 0.15)

    RotationAnimation on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.running
    }
}
