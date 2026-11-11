import QtQuick
import qs.core

// Something round in the middle of the orbit. It pops in and out as `shown`
// changes, so that the hub and the password prompt can take turns there.
FocusScope {
    property bool shown: true

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.85
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.normal }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack }
    }
}
