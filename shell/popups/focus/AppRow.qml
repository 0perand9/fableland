import QtQuick
import qs.core
import qs.widgets

// One application in the list: icon, name, time, and its share of the total
// as a meter. `app` is an entry of `apps` in `focus.stats`.
Clickable {
    id: root

    property var app: ({})
    readonly property real percent: app.percent ?? 0

    implicitHeight: Theme.px(48)

    AppIcon {
        id: icon

        x: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        icon: root.app.icon ?? ""
        fallback: root.app.class ?? ""
        glyph: Icons.window
        size: 28
    }

    Txt {
        id: name

        anchors.left: icon.right
        anchors.right: time.left
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: Theme.gap
        y: Theme.px(8)
        text: root.app.name ?? ""
        size: 13
        bold: true
    }

    Txt {
        id: time

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: name.verticalCenter
        text: Fmt.duration(root.app.seconds ?? 0)
        size: 12
        color: Theme.subtext
    }

    Rectangle {
        id: meter

        anchors.left: name.left
        anchors.right: share.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: share.verticalCenter
        height: Theme.px(4)
        radius: height / 2
        color: Theme.alpha(Theme.surface2, 0.5)

        Rectangle {
            width: Math.max(height, parent.width * root.percent / 100)
            height: parent.height
            radius: height / 2
            color: Theme.accent

            Behavior on width {
                NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
            }
        }
    }

    Txt {
        id: share

        anchors.right: time.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(7)
        width: Theme.px(38)
        horizontalAlignment: Text.AlignRight
        text: root.percent >= 0.1 ? root.percent.toFixed(root.percent >= 10 ? 0 : 1) + "%" : "<0.1%"
        size: 10
        color: Theme.dim
    }
}
