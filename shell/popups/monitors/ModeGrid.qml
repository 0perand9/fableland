import QtQuick
import qs.core
import qs.widgets
import "layout.js" as Layout

// The resolutions a monitor offers, two to a row, largest first.
GridView {
    id: root

    // Entries of Layout.resolutions().
    property var resolutions: []
    // `key` of the resolution in use.
    property string current: ""
    readonly property int currentAt: resolutions.findIndex(entry => entry.key === current)

    // Space between cells; each cell carries it on its right and below.
    readonly property int gap: Theme.px(6)

    signal chosen(var resolution)

    // Choose the entry `by` places further on, if there is one (for the arrow keys).
    function step(by) {
        const entry = resolutions[currentAt + by];
        if (entry)
            root.chosen(entry);
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cellWidth: Math.floor(width / 2)
    cellHeight: Theme.px(38)
    model: resolutions
    // Keep the resolution in use in sight, also when it changes from the keyboard.
    onCurrentAtChanged: positionViewAtIndex(currentAt, GridView.Contain)
    Component.onCompleted: positionViewAtIndex(currentAt, GridView.Contain)

    delegate: Item {
        id: cell

        required property var modelData
        readonly property bool isCurrent: modelData.key === root.current

        width: root.cellWidth
        height: root.cellHeight

        Clickable {
            anchors.fill: parent
            anchors.rightMargin: root.gap
            anchors.bottomMargin: root.gap
            fill: cell.isCurrent ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.surface1, 0.45)
            border.width: 1
            border.color: cell.isCurrent ? Theme.alpha(Theme.accent, 0.5) : "transparent"
            onClicked: root.chosen(cell.modelData)

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: cell.modelData.width + " × " + cell.modelData.height
                size: 12
                bold: cell.isCurrent
                color: cell.isCurrent ? Theme.accent : Theme.text
            }

            Txt {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: Layout.resolutionTag(cell.modelData.width, cell.modelData.height)
                size: 10
                color: cell.isCurrent ? Theme.accent : Theme.dim
            }
        }
    }

    Scroller {
        parent: root
        target: root
        // In the gap after the last column.
        x: root.width - width
        y: root.visibleArea.yPosition * root.height
    }
}
