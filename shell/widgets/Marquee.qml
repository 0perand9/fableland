import QtQuick
import qs.core

// One line of text that scrolls back and forth when it does not fit.
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias size: label.size
    property alias bold: label.bold
    property bool running: visible
    readonly property real overflow: Math.max(0, label.implicitWidth - width)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    onOverflowChanged: label.x = 0

    Txt {
        id: label

        elide: Text.ElideNone
        height: parent.height

        SequentialAnimation on x {
            running: root.running && root.overflow > 0
            loops: Animation.Infinite

            PauseAnimation { duration: 1800 }
            NumberAnimation { to: -root.overflow; duration: root.overflow * 28; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1800 }
            NumberAnimation { to: 0; duration: root.overflow * 28; easing.type: Easing.InOutSine }
        }
    }
}
