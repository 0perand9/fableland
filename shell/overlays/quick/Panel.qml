import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core

// The visible part of a dock: one frame attached to the screen edge that
// morphs from the handle into the strip of actions and on into an open module.
// The window spans the edge so the frame can sit anywhere along it, but only
// the frame takes input.
PanelWindow {
    id: panel

    required property var dock

    readonly property string edge: dock.edge
    readonly property bool vertical: edge !== "bottom"
    readonly property bool out: dock.stage !== "hidden"
    // What the frame shows — still the last stage while it fades out.
    property string stage: "handle"
    // 0 gone … 1 out.
    property real reveal: out ? 1 : 0
    // 0 the strip alone … 1 a module open beside it.
    property real openness: stage === "module" ? 1 : 0

    readonly property real stripDepth: Theme.px(52)
    // How far the window reaches into the screen: the strip, the largest module, the shadow.
    readonly property real reach: stripDepth + Theme.px(440) + Theme.px(48)

    readonly property size moduleSize: module.item ? Qt.size(module.item.implicitWidth, module.item.implicitHeight) : Qt.size(0, 0)
    // The frame's extent along the edge and into the screen, for the current stage.
    readonly property real span: stage === "handle" ? Theme.px(88) : stage === "strip" ? strip.length : Math.max(strip.length, vertical ? moduleSize.height : moduleSize.width)
    readonly property real depth: stage === "handle" ? Theme.px(10) : stage === "strip" ? stripDepth : stripDepth + (vertical ? moduleSize.width : moduleSize.height)
    // Centred on the pointer's position, as far as the frame then stays on the screen.
    readonly property real center: {
        const half = span / 2 + Theme.px(8);
        const at = dock.along - (vertical ? Theme.barZone : 0);
        return Math.max(half, Math.min((vertical ? height : width) - half, at));
    }

    // Towards the middle of the screen, in pixels, for a movement of the pointer.
    function inward(dx, dy) {
        return edge === "left" ? dx : edge === "right" ? -dx : -dy;
    }

    screen: dock.screen
    visible: out || reveal > 0
    anchors {
        left: panel.edge !== "right"
        right: panel.edge !== "left"
        top: panel.vertical
        bottom: true
    }
    margins.top: vertical ? Theme.barZone : 0
    implicitWidth: reach
    implicitHeight: reach
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-quick"
    // Keys work once the panel has been clicked; it never grabs them.
    WlrLayershell.keyboardFocus: out && stage !== "handle" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: grasp
    }

    Behavior on reveal {
        NumberAnimation { duration: panel.out ? 220 : 160; easing.type: Easing.OutCubic }
    }
    Behavior on openness {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    Connections {
        target: panel.dock

        function onStageChanged() {
            if (panel.out)
                panel.stage = panel.dock.stage;
        }
    }

    Component.onCompleted: stage = dock.stage

    // The frame plus a little around it: the pointer here keeps the panel out.
    FocusScope {
        id: grasp

        readonly property real slack: Theme.px(10)
        // The frame's geometry, animated — except when it appears, which happens in place.
        readonly property bool morphing: panel.reveal > 0
        property real span: panel.span
        property real depth: panel.depth
        property real center: panel.center
        // It slides out of the edge while it appears.
        readonly property real tuck: (1 - panel.reveal) * Theme.px(16)
        readonly property real across: panel.edge === "left" ? -tuck : (panel.vertical ? panel.width : panel.height) - depth + tuck

        x: (panel.vertical ? across : center - span / 2) - slack
        y: (panel.vertical ? center - span / 2 : across) - slack
        width: (panel.vertical ? depth : span) + 2 * slack
        height: (panel.vertical ? span : depth) + 2 * slack
        focus: true
        Keys.onEscapePressed: panel.dock.back()
        Keys.onTabPressed: panel.dock.cycle(1)
        Keys.onBacktabPressed: panel.dock.cycle(-1)

        Behavior on span {
            enabled: grasp.morphing
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on depth {
            enabled: grasp.morphing
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on center {
            enabled: grasp.morphing
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            onHoveredChanged: panel.dock.panelHovered = hovered
        }

        RectangularShadow {
            anchors.fill: frame
            radius: frame.round
            blur: Theme.px(32)
            offset.y: Theme.px(6)
            color: Theme.shadow
            opacity: panel.reveal
        }

        ClippingRectangle {
            id: frame

            // Rounded towards the screen, square against the edge.
            readonly property real round: Math.min(Theme.radiusLarge, grasp.depth)

            anchors.fill: parent
            anchors.margins: grasp.slack
            opacity: panel.reveal
            color: Theme.alpha(Theme.base, 0.95)
            border.width: 1
            border.color: Theme.border
            topLeftRadius: panel.edge === "left" ? 0 : round
            topRightRadius: panel.edge === "right" ? 0 : round
            bottomLeftRadius: panel.edge === "right" ? round : 0
            bottomRightRadius: panel.edge === "left" ? round : 0

            // The handle's grip.
            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(panel.vertical ? 3 : 30)
                height: Theme.px(panel.vertical ? 30 : 3)
                radius: Theme.px(1.5)
                color: Theme.accent
                opacity: panel.stage === "handle" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.fast }
                }
            }

            Strip {
                id: strip

                dock: panel.dock
                vertical: panel.vertical
                moduleOpen: panel.stage === "module"
                // Against the screen edge, centred along it.
                x: panel.vertical ? (panel.edge === "left" ? 0 : parent.width - width) : (parent.width - width) / 2
                y: panel.vertical ? (parent.height - height) / 2 : parent.height - height
                width: panel.vertical ? panel.stripDepth : length
                height: panel.vertical ? length : panel.stripDepth
                opacity: panel.stage === "handle" ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }
            }

            // The hairline between the strip and the module.
            Rectangle {
                x: panel.vertical ? (panel.edge === "left" ? panel.stripDepth : parent.width - panel.stripDepth - 1) : 0
                y: panel.vertical ? 0 : parent.height - panel.stripDepth - 1
                width: panel.vertical ? 1 : parent.width
                height: panel.vertical ? parent.height : 1
                color: Theme.border
                opacity: panel.openness
            }

            // The open module. It keeps its size and place while the frame grows over it,
            // and stays alive until the frame has closed again.
            Loader {
                id: module

                readonly property var action: panel.dock.actions.find(action => action.id === panel.dock.module)

                x: panel.vertical ? (panel.edge === "left" ? panel.stripDepth : parent.width - panel.stripDepth - width) : (parent.width - width) / 2
                y: panel.vertical ? (parent.height - height) / 2 : parent.height - panel.stripDepth - height
                active: panel.visible && (panel.stage === "module" || panel.openness > 0)
                source: action.view
                opacity: panel.openness
                focus: true
                onLoaded: arrive.restart()

                NumberAnimation {
                    id: arrive

                    target: module.item
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.normal
                }
            }
        }

        // The handle: a click brings out the strip, pulling it inwards opens the last module.
        MouseArea {
            property point pressedAt
            property bool pulled: false

            anchors.fill: parent
            enabled: panel.stage === "handle"
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                pressedAt = Qt.point(mouse.x, mouse.y);
                pulled = false;
            }
            onPositionChanged: mouse => {
                if (!pulled && panel.inward(mouse.x - pressedAt.x, mouse.y - pressedAt.y) > Theme.px(15)) {
                    pulled = true;
                    panel.dock.open(panel.dock.module);
                }
            }
            // Letting go after a pull is not a click.
            onClicked: {
                if (!pulled)
                    panel.dock.stage = "strip";
            }
        }
    }
}
