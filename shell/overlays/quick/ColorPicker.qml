import QtQuick
import Quickshell.Widgets
import qs.core

// Any colour: a field of saturation × brightness above a strip of hues.
// It shows `color` and reports what the user picks; it does not change itself.
// (The plain white, black and rainbow below are the colour model's axes, not theme colours.)
Item {
    id: picker

    property color color
    // The hue on show. Kept apart from `color`, because greys have no hue: the
    // field would snap back to red whenever the reticle passes through them.
    property real hue: 0

    signal picked(color color)

    function unit(value) {
        return Math.max(0, Math.min(1, value));
    }

    implicitWidth: Theme.px(228)
    implicitHeight: field.height + strip.height + Theme.px(10)
    onColorChanged: {
        if (color.hsvHue >= 0 && color.hsvSaturation > 0)
            hue = color.hsvHue;
    }

    ClippingRectangle {
        id: field

        width: parent.width
        height: Theme.px(132)
        radius: Theme.radiusSmall
        color: Qt.hsva(picker.hue, 1, 1, 1)

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0; color: Qt.hsva(0, 0, 1, 1) }
                GradientStop { position: 1; color: Qt.hsva(0, 0, 1, 0) }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.hsva(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.hsva(0, 0, 0, 1) }
            }
        }

        Rectangle {
            x: picker.color.hsvSaturation * parent.width - width / 2
            y: (1 - picker.color.hsvValue) * parent.height - height / 2
            width: Theme.px(14)
            height: width
            radius: width / 2
            color: picker.color
            border.width: Theme.px(2)
            border.color: Qt.hsva(0, 0, 1, 1)
        }

        MouseArea {
            function pick(mouse) {
                picker.picked(Qt.hsva(picker.hue, picker.unit(mouse.x / width), 1 - picker.unit(mouse.y / height), 1));
            }

            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.CrossCursor
            onPressed: mouse => pick(mouse)
            onPositionChanged: mouse => pick(mouse)
        }
    }

    Rectangle {
        id: strip

        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(14)
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6, 1, 1, 1) }
            GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
            GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
            GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
            GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
            GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
            GradientStop { position: 6 / 6; color: Qt.hsva(0, 1, 1, 1) }
        }

        Rectangle {
            x: picker.hue * (parent.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(8)
            height: parent.height + Theme.px(6)
            radius: width / 2
            color: Qt.hsva(picker.hue, 1, 1, 1)
            border.width: Theme.px(2)
            border.color: Qt.hsva(0, 0, 1, 1)
        }

        MouseArea {
            function pick(mouse) {
                // Short of 1, which is red again and would throw the handle back to the start.
                picker.hue = Math.min(0.999, picker.unit(mouse.x / width));
                picker.picked(Qt.hsva(picker.hue, picker.color.hsvSaturation, picker.color.hsvValue, 1));
            }

            anchors.fill: parent
            // A little taller than the strip, to be easy to grab.
            anchors.topMargin: -Theme.px(5)
            anchors.bottomMargin: -Theme.px(5)
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => pick(mouse)
            onPositionChanged: mouse => pick(mouse)
        }
    }
}
