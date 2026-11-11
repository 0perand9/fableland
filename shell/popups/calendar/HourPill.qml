import QtQuick
import qs.core
import qs.widgets

// One hour of the forecast: when, what the sky does, how warm.
Rectangle {
    id: pill

    property string time: ""
    property string condition: ""
    property real temperature: 0
    // The hour that is on right now.
    property bool current: false
    readonly property bool hovered: hover.hovered

    width: Theme.px(56)
    height: Theme.px(94)
    radius: width / 2
    color: current ? Theme.accent : hovered ? Theme.surface2 : Theme.surface0
    border.width: 1
    border.color: current ? "transparent" : hovered ? Theme.alpha(Theme.accent, 0.7) : Theme.border

    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }

    HoverHandler {
        id: hover
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(5)

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: pill.time
            size: 11
            bold: true
            color: pill.current ? Theme.accentText : pill.hovered ? Theme.text : Theme.dim
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.weather(pill.condition)
            size: 20
            color: pill.current ? Theme.accentText : Theme.weatherColor(pill.condition)
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(pill.temperature) + "°"
            size: 14
            bold: true
            color: pill.current ? Theme.accentText : Theme.text
        }
    }
}
