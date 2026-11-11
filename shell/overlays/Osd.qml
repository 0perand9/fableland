import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.widgets

// A brief on-screen display when the volume or brightness changes through keys.
PanelWindow {
    id: osd

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false
    readonly property color hue: kind === "brightness" ? Theme.yellow : Theme.peach

    screen: Ui.focusedScreen
    visible: shown || pill.opacity > 0
    anchors.bottom: true
    margins.bottom: Theme.px(90)
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.px(300)
    implicitHeight: Theme.px(56)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-osd"
    // Never takes input.
    mask: Region {}

    Connections {
        target: Daemon

        function onEvent(name, data) {
            // The mixer already shows the volume while it is open.
            if (name !== "osd" || !Daemon.setting("osd", true) || Ui.locked || (data.kind === "volume" && Ui.current === "volume"))
                return;
            osd.kind = data.kind;
            osd.value = data.value;
            osd.muted = !!data.muted;
            osd.shown = true;
            hide.restart();
        }
    }

    Timer {
        id: hide

        interval: 1400
        onTriggered: osd.shown = false
    }

    // Development preview: `dev/shot osd`.
    Component.onCompleted: {
        if (Ui.dev === "osd") {
            value = 65;
            shown = true;
        }
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.base, 0.92)
        border.width: 1
        border.color: Theme.border
        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
        }

        Icon {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            text: osd.kind === "brightness" ? Icons.brightnessLevel(osd.value) : Icons.volume(osd.value, osd.muted)
            size: 22
            color: osd.muted ? Theme.dim : osd.hue
        }

        Rectangle {
            anchors.left: icon.right
            anchors.right: label.left
            anchors.leftMargin: Theme.px(14)
            anchors.rightMargin: Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.px(6)
            radius: height / 2
            color: Theme.alpha(Theme.surface2, 0.6)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, osd.value / 100))
                height: parent.height
                radius: height / 2
                color: osd.muted ? Theme.dim : osd.hue

                Behavior on width {
                    NumberAnimation { duration: Theme.fast }
                }
            }
        }

        Txt {
            id: label

            anchors.right: parent.right
            anchors.rightMargin: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(36)
            horizontalAlignment: Text.AlignRight
            text: Math.round(osd.value)
            size: 14
            bold: true
        }
    }
}
