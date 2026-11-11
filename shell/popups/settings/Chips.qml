import QtQuick
import qs.core
import qs.widgets

// A set of options as chips that wrap over as many lines as they need; one is chosen.
Flow {
    id: root

    property var labels: []
    property int current: -1

    signal picked(int index)

    spacing: Theme.px(6)

    Repeater {
        model: root.labels

        Clickable {
            id: chip

            required property string modelData
            required property int index
            readonly property bool chosen: index === root.current

            width: name.implicitWidth + Theme.px(24)
            height: Theme.px(28)
            radius: height / 2
            fill: chosen ? Theme.accent : Theme.alpha(Theme.surface2, 0.5)
            tint: chosen ? Theme.accentText : Theme.text
            onClicked: root.picked(index)

            Txt {
                id: name

                anchors.centerIn: parent
                text: chip.modelData
                size: 12
                bold: chip.chosen
                color: chip.chosen ? Theme.accentText : Theme.subtext
            }
        }
    }
}
