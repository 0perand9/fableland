import QtQuick
import qs.core
import qs.widgets

// The sidebar's navigation: one entry per page, with the stretchy pill on the
// current one. It scrolls if the screen is too short for all of them.
Flickable {
    id: root

    // [{ title, short?, icon }] — `short` replaces a title too long for the rail.
    property var pages: []
    // The page on show; -1 while a search shows matches from all of them.
    property int current: 0

    signal selected(int index)

    readonly property real cell: Theme.px(50)
    readonly property real gap: Theme.px(4)

    function reveal(index) {
        const top = index * cell;
        if (top < contentY)
            contentY = top;
        else if (top + cell > contentY + height)
            contentY = top + cell - height;
    }

    implicitWidth: Theme.px(66)
    contentHeight: pages.length * cell
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onCurrentChanged: {
        if (current >= 0)
            reveal(current);
    }

    Stretch {
        vertical: true
        width: root.width
        radius: Theme.radiusSmall
        // While nothing is selected the pill waits, hidden, where it last was.
        targetStart: Math.max(0, root.current) * root.cell + root.gap / 2
        targetEnd: targetStart + root.cell - root.gap
        opacity: root.current >= 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Repeater {
        model: root.pages

        Item {
            id: entry

            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.current
            readonly property color ink: isCurrent ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

            y: index * root.cell
            width: root.width
            height: root.cell

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: root.gap / 2
                anchors.bottomMargin: root.gap / 2
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.text, hover.containsMouse && !entry.isCurrent ? 0.07 : 0)

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(2)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: entry.modelData.icon
                    size: 19
                    color: entry.ink

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: entry.modelData.short ?? entry.modelData.title
                    size: 9
                    bold: entry.isCurrent
                    color: entry.ink

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
                onClicked: root.selected(entry.index)
            }
        }
    }
}
