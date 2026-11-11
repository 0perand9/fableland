import QtQuick
import qs.core

// A segmented control. `model` is a list of labels or of { label, icon } objects.
// Like Toggle it does not select by itself: bind `current` and update it in onSelected.
Rectangle {
    id: root

    property var model: []
    property int current: 0
    property color accentColor: Theme.accent
    property real size: 13

    signal selected(int index)

    implicitHeight: Theme.px(40)
    implicitWidth: Theme.px(120) * model.length
    radius: height / 2
    color: Theme.alpha(Theme.surface0, 0.6)

    readonly property real inset: Theme.px(4)
    readonly property real tabWidth: model.length > 0 ? (width - 2 * inset) / model.length : 0

    Stretch {
        y: root.inset
        height: root.height - 2 * root.inset
        targetStart: root.inset + root.current * root.tabWidth
        targetEnd: targetStart + root.tabWidth
        color: root.accentColor
        visible: root.current >= 0 && root.current < root.model.length
    }

    Repeater {
        model: root.model

        Item {
            id: tab

            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.current
            readonly property string label: typeof modelData === "string" ? modelData : (modelData.label ?? "")
            readonly property string icon: typeof modelData === "string" ? "" : (modelData.icon ?? "")

            x: root.inset + index * root.tabWidth
            y: root.inset
            width: root.tabWidth
            height: root.height - 2 * root.inset

            Row {
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Icon {
                    visible: tab.icon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.icon
                    size: root.size + 4
                    color: label.color
                }

                Txt {
                    id: label

                    visible: tab.label !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.label
                    size: root.size
                    bold: true
                    color: tab.isCurrent ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(tab.index)
            }
        }
    }
}
