import QtQuick
import qs.core

// A line of keyboard hints: a key cap and what the key does.
//   KeyHints { model: [{ key: "Enter", label: "Launch" }] }
Row {
    id: root

    property var model: []

    spacing: Theme.px(14)

    Repeater {
        model: root.model

        Row {
            id: hint

            required property var modelData

            spacing: Theme.px(6)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(height, cap.implicitWidth + Theme.px(10))
                height: Theme.px(20)
                radius: Theme.px(6)
                color: Theme.alpha(Theme.surface1, 0.7)
                border.width: 1
                border.color: Theme.border

                Txt {
                    id: cap

                    anchors.centerIn: parent
                    text: hint.modelData.key
                    size: 10
                    bold: true
                    color: Theme.subtext
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: hint.modelData.label
                size: 11
                color: Theme.dim
            }
        }
    }
}
