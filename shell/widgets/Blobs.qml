import QtQuick
import QtQuick.Shapes
import qs.core

// Soft blobs of colour drifting behind a popup's content.
Item {
    id: root

    property var colors: [Theme.accent, Theme.blue, Theme.pink]
    property real strength: 0.16
    // 1 is the usual pace; 0 stands still.
    property real speed: 1
    property bool running: visible
    property real t: 0

    clip: true

    NumberAnimation on t {
        from: 0
        to: 2 * Math.PI
        duration: 48000 / Math.max(root.speed, 0.01)
        loops: Animation.Infinite
        // Told to rest, they hold their place and carry on from there.
        running: root.speed > 0
        paused: running && !root.running
    }

    Repeater {
        model: root.colors

        Shape {
            id: blob

            required property color modelData
            required property int index
            readonly property real diameter: Math.max(root.width, root.height) * (0.75 - index * 0.08)
            readonly property real angle: root.t * (index % 2 === 0 ? 1 : -1) * (1 + index * 0.5) + index * 2.1

            x: root.width * (0.5 + 0.34 * Math.cos(angle)) - diameter / 2
            y: root.height * (0.5 + 0.3 * Math.sin(angle * 0.8 + index)) - diameter / 2
            width: diameter
            height: diameter

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: blob.diameter / 2
                    centerY: blob.diameter / 2
                    focalX: centerX
                    focalY: centerY
                    centerRadius: blob.diameter / 2

                    GradientStop { position: 0; color: Theme.alpha(blob.modelData, root.strength) }
                    GradientStop { position: 1; color: Theme.alpha(blob.modelData, 0) }
                }

                PathRectangle {
                    width: blob.diameter
                    height: blob.diameter
                }
            }
        }
    }
}
