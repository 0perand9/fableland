import QtQuick
import qs.core
import qs.widgets

// A small pill: a glyph, or an application's icon, and a label.
Clickable {
    id: root

    property string glyph: ""
    property color glyphColor: Theme.subtext
    // An application or theme icon, shown instead of the glyph when set.
    property string appIcon: ""
    property string text: ""
    property real maxWidth: Theme.px(220)

    readonly property real padding: Theme.px(10)

    implicitWidth: content.implicitWidth + 2 * padding
    implicitHeight: Theme.px(26)
    radius: height / 2
    fill: Theme.alpha(Theme.surface1, 0.55)

    Row {
        id: content

        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(6)

        Item {
            id: leading

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(16)
            height: width

            AppIcon {
                anchors.centerIn: parent
                visible: root.appIcon !== ""
                icon: root.appIcon
                glyph: root.glyph
                size: 16
            }

            Icon {
                anchors.centerIn: parent
                visible: root.appIcon === ""
                text: root.glyph
                size: 15
                color: root.glyphColor
            }
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxWidth - 2 * root.padding - leading.width - content.spacing)
            text: root.text
            size: 11
            bold: true
            color: Theme.subtext
        }
    }
}
