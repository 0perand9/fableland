import QtQuick
import qs.core
import qs.widgets

// A key combination such as "SUPER + SHIFT + D", drawn as key caps.
Row {
    id: root

    property string keys: ""

    spacing: Theme.px(4)

    Repeater {
        model: root.keys.split("+").map(part => part.trim()).filter(part => part !== "")

        Rectangle {
            required property string modelData

            width: Math.max(height, cap.implicitWidth + Theme.px(12))
            height: Theme.px(22)
            radius: Theme.px(6)
            color: Theme.alpha(Theme.surface2, 0.7)
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.14)

            Txt {
                id: cap

                anchors.centerIn: parent
                text: parent.modelData
                size: 10.5
                bold: true
                color: Theme.accent
            }
        }
    }
}
