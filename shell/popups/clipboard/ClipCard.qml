import QtQuick
import qs.core
import qs.widgets

// One clipboard entry in the grid: the first lines of a text, or a thumbnail.
// The grid's highlight shows through the selected card.
Clickable {
    id: root

    // Position in the history, counted from 1.
    property int number: 0
    property string kind: "text"
    // The start of the text; for an image, its size and dimensions.
    property string text: ""
    // The image's file, for images.
    property string image: ""
    property bool selected: false

    readonly property bool isImage: kind === "image"

    signal removeRequested

    radius: Theme.radius
    fill: selected ? "transparent" : Theme.alpha(Theme.surface0, hovered ? 0.85 : 0.45)
    border.width: 1
    border.color: selected ? "transparent" : Theme.border
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Rectangle {
        id: badge

        x: Theme.px(8)
        y: Theme.px(8)
        width: Math.max(height, ordinal.implicitWidth + Theme.px(10))
        height: Theme.px(22)
        radius: Theme.px(7)
        color: root.selected ? Theme.accent : Theme.alpha(Theme.surface2, 0.6)

        Txt {
            id: ordinal

            anchors.centerIn: parent
            text: root.number
            size: 10
            bold: true
            color: root.selected ? Theme.accentText : Theme.subtext
        }
    }

    Txt {
        anchors.left: badge.right
        anchors.leftMargin: Theme.px(8)
        anchors.right: remove.left
        anchors.verticalCenter: badge.verticalCenter
        visible: root.isImage
        text: root.text
        size: 10
        color: Theme.dim
    }

    IconBtn {
        id: remove

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(6)
        anchors.verticalCenter: badge.verticalCenter
        // Its own hover counts too: the card stops being hovered once the pointer is on the button.
        visible: root.hovered || hovered
        icon: Icons.trash
        size: 24
        iconColor: Theme.subtext
        onClicked: root.removeRequested()
    }

    Txt {
        anchors.top: badge.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(8)
        anchors.bottomMargin: Theme.px(10)
        x: Theme.px(12)
        width: parent.width - 2 * x
        visible: !root.isImage
        text: root.text
        size: 12
        bold: root.selected
        wrapMode: Text.Wrap
        maximumLineCount: 4
        verticalAlignment: Text.AlignTop
    }

    RoundImage {
        anchors.fill: parent
        anchors.margins: Theme.px(8)
        anchors.topMargin: Theme.px(38)
        visible: root.isImage
        radius: Theme.px(8)
        color: Theme.alpha(root.selected ? Theme.crust : Theme.surface1, 0.5)
        source: root.isImage ? Fmt.file(root.image) : ""
        // Screenshots come in every shape; show all of each.
        fillMode: Image.PreserveAspectFit
    }
}
