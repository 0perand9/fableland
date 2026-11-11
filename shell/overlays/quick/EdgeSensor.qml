import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// A one-pixel window along a screen edge that tells its dock where the pointer
// touches it. It is all that exists of the panel while it is hidden.
PanelWindow {
    id: sensor

    required property var dock
    required property string edge       // left | right | bottom
    readonly property bool vertical: edge !== "bottom"

    screen: dock.screen
    anchors {
        left: sensor.edge !== "right"
        right: sensor.edge !== "left"
        top: sensor.vertical
        bottom: true
    }
    // The side sensors start below the bar, leaving its corners alone.
    margins.top: vertical ? Theme.barZone : 0
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-quick-edge"

    MouseArea {
        // Where on the edge the pointer is, in screen coordinates.
        function report() {
            sensor.dock.touch(sensor.edge, sensor.vertical ? mouseY + Theme.barZone : mouseX);
        }

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: report()
        onPositionChanged: report()
        onExited: sensor.dock.untouch()
    }
}
