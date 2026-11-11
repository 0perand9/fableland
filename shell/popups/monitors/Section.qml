import QtQuick
import qs.core
import qs.widgets

// One setting of the selected monitor: a caption, its present value, and the
// control underneath. The section that has the keyboard is marked; the arrow
// keys change its value (see Monitors.qml).
Item {
    id: root

    property string title: ""
    // The setting in words, shown beside the caption.
    property string value: ""
    // The arrow keys act on this section.
    property bool current: false
    default property alias content: holder.data

    implicitHeight: holder.y + holder.height

    Rectangle {
        id: mark

        anchors.verticalCenter: caption.verticalCenter
        width: root.current ? Theme.px(3) : 0
        height: Theme.px(11)
        radius: width / 2
        color: Theme.accent

        Behavior on width {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Txt {
        id: caption

        x: root.current ? mark.width + Theme.px(6) : 0
        text: root.title
        size: 11
        bold: true
        color: root.current ? Theme.accent : Theme.subtext

        Behavior on x {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.left: caption.right
        anchors.leftMargin: Theme.px(12)
        anchors.verticalCenter: caption.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.value
        size: 11
        color: Theme.dim
    }

    Item {
        id: holder

        y: caption.height + Theme.px(8)
        width: parent.width
        height: childrenRect.height
    }
}
