import QtQuick
import qs.core

// What moves behind a popup's content. The popup says which colours it has;
// the pattern, how strong and how fast it is are the user's choice
// (Settings → Appearance → Backdrop).
//
// "blobs" are drifting patches of colour (Blobs.qml). Every other pattern is a
// fragment shader, backdrop/<style>.frag, and answers to the pointer;
// backdrop/common.glsl says what a pattern is given.
Item {
    id: root

    property var colors: [Theme.accent, Theme.blue, Theme.pink]
    // How much backdrop this popup wants — 0.16 is the usual amount — before the user's say.
    property real strength: 0.16
    property bool running: visible

    readonly property string style: Daemon.setting("backdrop.style", "contours")
    readonly property real gain: Daemon.setting("backdrop.strength", 100) / 100
    readonly property real speed: Daemon.setting("backdrop.speed", 100) / 100
    readonly property bool reactive: Daemon.setting("backdrop.reactive", true)

    Loader {
        anchors.fill: parent
        sourceComponent: root.style === "none" ? null : root.style === "blobs" ? blobs : pattern
    }

    Component {
        id: blobs

        Blobs {
            colors: root.colors
            strength: root.strength * root.gain
            speed: root.speed
            running: root.running
        }
    }

    Component {
        id: pattern

        ShaderEffect {
            id: effect

            // The uniforms of backdrop/common.glsl.
            property real time: 0
            readonly property real strength: root.strength / 0.16 * root.gain
            property real pull: hover.hovered ? 1 : 0
            readonly property real unit: Theme.scale
            readonly property vector2d size: Qt.vector2d(width, height)
            readonly property vector2d pointer: Qt.vector2d(pointerX, pointerY)
            readonly property color tintA: root.colors[0] ?? Theme.accent
            readonly property color tintB: root.colors[1] ?? tintA
            readonly property color tintC: root.colors[2] ?? tintB

            // The pointer, followed with a little lag so that the pattern flows after it.
            property real pointerX: width / 2
            property real pointerY: height / 2

            fragmentShader: Qt.resolvedUrl("backdrop/" + root.style + ".frag.qsb")

            Behavior on pull {
                NumberAnimation { duration: Theme.slow }
            }
            Behavior on pointerX {
                SmoothedAnimation { duration: 260; velocity: -1 }
            }
            Behavior on pointerY {
                SmoothedAnimation { duration: 260; velocity: -1 }
            }

            // An hour of seconds, on the render thread: the pattern costs the interface nothing.
            // Told to rest, it holds its place and carries on from there.
            UniformAnimator on time {
                from: 0
                to: 3600
                duration: 3600000 / Math.max(root.speed, 0.01)
                loops: Animation.Infinite
                running: root.speed > 0
                paused: running && !root.running
            }

            // Over the whole popup, its content included.
            HoverHandler {
                id: hover

                parent: root.parent
                enabled: root.reactive
                onPointChanged: {
                    if (!hovered)
                        return;
                    effect.pointerX = point.position.x;
                    effect.pointerY = point.position.y;
                }
            }
        }
    }
}
