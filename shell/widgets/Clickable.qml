import QtQuick
import qs.core

// A surface that reacts to the pointer. The base of every button-like widget:
// it shows hover/press feedback in `tint` on top of `fill` and reports clicks.
Rectangle {
    id: root

    property color fill: "transparent"
    property color tint: Theme.text
    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton
    property alias cursorShape: mouse.cursorShape
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked(var mouse)
    signal wheel(var wheel)

    radius: Theme.radiusSmall
    color: {
        const strength = !interactive ? 0 : pressed ? 0.18 : hovered ? 0.1 : 0;
        if (strength === 0)
            return fill;
        // Tinting "transparent" would blend towards black, so an unfilled surface is the tint alone.
        return fill.a === 0 ? Theme.alpha(tint, strength) : Qt.tint(fill, Theme.alpha(tint, strength));
    }

    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: root.acceptedButtons
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => {
            // Only swallow the wheel when somebody listens; otherwise let lists scroll.
            wheel.accepted = false;
            root.wheel(wheel);
        }
    }
}
