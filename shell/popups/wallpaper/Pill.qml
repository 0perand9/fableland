import QtQuick
import qs.core

// The rounded strip that groups controls in the picker's top row.
Rectangle {
    readonly property int inset: Theme.px(4)

    implicitHeight: Theme.px(44)
    radius: height / 2
    color: Theme.alpha(Theme.surface0, 0.6)
    border.width: 1
    border.color: Theme.border
}
