import QtQuick
import qs.core
import qs.widgets

// One day of the month grid.
Clickable {
    id: cell

    property int day: 1
    // False for the days of the neighbouring months that fill the first and last week.
    property bool inMonth: true
    property bool today: false
    property bool selected: false
    property bool hasNote: false

    radius: Theme.radiusSmall
    fill: today ? Theme.accent : selected ? Theme.alpha(Theme.accent, 0.14) : "transparent"
    tint: today ? Theme.accentText : Theme.text
    border.width: selected && !today ? Math.max(1, Theme.px(1.5)) : 0
    border.color: Theme.accent
    scale: hovered ? 1.12 : 1
    // The hovered day pops out over its neighbours.
    z: hovered ? 1 : 0

    Behavior on scale {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
    }

    Txt {
        anchors.centerIn: parent
        text: cell.day
        size: 13
        bold: cell.today || cell.selected
        color: cell.today ? Theme.accentText : cell.inMonth ? Theme.text : Theme.alpha(Theme.dim, 0.55)
    }

    // The mark of a diary entry.
    Rectangle {
        visible: cell.hasNote
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(5)
        width: Theme.px(4)
        height: width
        radius: width / 2
        color: cell.today ? Theme.accentText : Theme.accent
        opacity: cell.inMonth ? 1 : 0.5
    }
}
