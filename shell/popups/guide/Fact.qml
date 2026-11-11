import QtQuick
import qs.core
import qs.widgets

// One line of system information: a glyph, what it is and its value.
Item {
    id: root

    property string icon: ""
    property string caption: ""
    property string value: ""

    implicitHeight: Theme.px(36)

    Icon {
        id: glyph

        width: Theme.px(26)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 20
        color: Theme.accent
    }

    Column {
        anchors.left: glyph.right
        anchors.right: parent.right
        anchors.leftMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter

        Txt {
            width: parent.width
            text: root.caption
            size: 10
            color: Theme.dim
        }

        Txt {
            width: parent.width
            text: root.value || "unknown"
            size: 12
        }
    }
}
