import QtQuick
import QtQuick.Effects
import qs.core
import qs.widgets

// A record pressed from the cover art. It turns while `spinning` and keeps its
// angle when the music pauses.
Item {
    id: root

    // The cover as an image URL ("" = none).
    property string art: ""
    property bool spinning: false
    // Colour of the rim and the halo, usually taken from the cover.
    property color glow: Theme.accent

    readonly property real degreesPerSecond: 45

    implicitWidth: Theme.px(200)
    implicitHeight: Theme.px(200)
    // The record sits back a little while nothing plays.
    scale: spinning ? 1 : 0.92

    Behavior on scale {
        NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack }
    }

    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        blur: Theme.px(36)
        color: Theme.alpha(root.glow, root.spinning ? 0.5 : 0)

        Behavior on color {
            ColorAnimation { duration: Theme.slow }
        }
    }

    Rectangle {
        id: disc

        anchors.fill: parent
        radius: width / 2
        color: Theme.crust
        border.width: Theme.px(3)
        border.color: root.spinning ? root.glow : Theme.surface2

        Behavior on border.color {
            ColorAnimation { duration: Theme.slow }
        }

        RoundImage {
            id: cover

            anchors.fill: parent
            anchors.margins: disc.border.width
            radius: width / 2
            color: Theme.mantle
            source: root.art
        }

        // Grooves.
        Repeater {
            model: 3

            Rectangle {
                required property int index

                anchors.centerIn: parent
                width: disc.width * (0.86 - index * 0.17)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: cover.loaded ? Theme.alpha(Theme.base, 0.3) : Theme.alpha(Theme.text, 0.07)
            }
        }
    }

    // The centre stays upright: a spindle hole on a cover, a label with a note without one.
    Rectangle {
        anchors.centerIn: parent
        width: Theme.px(cover.loaded ? 38 : 84)
        height: width
        radius: width / 2
        color: cover.loaded ? Theme.alpha(Theme.base, 0.85) : Theme.alpha(root.glow, 0.16)
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.12)

        Behavior on width {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Icon {
            anchors.centerIn: parent
            visible: !cover.loaded
            text: Icons.musicNote
            size: 40
            color: root.glow
        }

        Rectangle {
            anchors.centerIn: parent
            visible: cover.loaded
            width: Theme.px(8)
            height: width
            radius: width / 2
            color: Theme.surface2
        }
    }

    FrameAnimation {
        running: root.spinning && root.visible
        onTriggered: disc.rotation = (disc.rotation + frameTime * root.degreesPerSecond) % 360
    }
}
