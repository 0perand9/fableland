import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core

// Shows the popup named by Ui.current inside one frame that fades in, morphs
// from popup to popup and fades out. The window exists only while it is needed
// and covers the screen so that a click anywhere else closes the popup; the
// bar stays clickable through it.
PanelWindow {
    id: host

    property Item page: null        // the popup on show
    property Item leaving: null     // the previous popup, fading out
    property bool open: false
    // Geometry changes are animated, except for the jump to a newly opened popup's place.
    property bool morphing: false
    // 0 hidden … 1 fully shown.
    property real reveal: open ? 1 : 0

    readonly property string placement: page ? page.placement : "center"
    readonly property rect target: {
        if (!page)
            return Qt.rect(0, 0, 0, 0);
        const margin = Theme.px(8), top = Theme.barZone + Theme.px(4);
        const w = Math.min(page.implicitWidth, width - 2 * margin);
        const h = Math.min(page.implicitHeight, height - top - margin);
        switch (placement) {
        case "top": return Qt.rect((width - w) / 2, top, w, h);
        case "top-left": return Qt.rect(margin, top, w, h);
        case "top-right": return Qt.rect(width - w - margin, top, w, h);
        case "bottom": return Qt.rect((width - w) / 2, height - h - margin, w, h);
        case "left": return Qt.rect(0, 0, w, height);
        case "right": return Qt.rect(width - w, 0, w, height);
        case "wide": return Qt.rect(0, (height - h) / 2, width, h);
        default: return Qt.rect((width - w) / 2, Math.max(top, (height - h) / 2), w, h);
        }
    }

    function show(name) {
        const component = Qt.createComponent(Ui.fileFor(name));
        if (component.status !== Component.Ready) {
            console.error("fable: cannot load popup '" + name + "':", component.errorString());
            Ui.close();
            return;
        }
        if (leaving)
            leaving.destroy();
        leaving = page;
        // A popup replacing another morphs the frame; a fresh one appears in place.
        morphing = open && reveal > 0;
        page = component.createObject(pages, { arg: Ui.arg, opacity: 0 });
        open = true;
        swap.restart();
        page.forceActiveFocus();
        Qt.callLater(() => host.morphing = true);
    }

    function cleanup() {
        if (leaving)
            leaving.destroy();
        if (page)
            page.destroy();
        leaving = null;
        page = null;
    }

    screen: Ui.screen ?? Quickshell.screens[0]
    visible: open || reveal > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Everything takes input except the bar's strip — unless the popup itself covers it.
    mask: Region {
        item: everything

        Region {
            item: barStrip
            intersection: Intersection.Subtract
        }

        Region {
            item: frame
            intersection: Intersection.Combine
        }
    }

    onRevealChanged: {
        if (reveal === 0 && !open)
            cleanup();
    }

    Behavior on reveal {
        NumberAnimation { duration: host.open ? 230 : 160; easing.type: Easing.OutCubic }
    }

    Connections {
        target: Ui

        function onCurrentChanged() {
            if (Ui.current === "")
                host.open = false;
            else
                host.show(Ui.current);
        }

        function onArgChanged() {
            if (host.page)
                host.page.arg = Ui.arg;
        }
    }

    // Compile the popups in the background once the shell has settled, so the first open is instant.
    Timer {
        property int next: 0
        property var warm: []

        interval: 150
        repeat: true
        running: Daemon.ready && next < Ui.popups.length
        onTriggered: warm.push(Qt.createComponent(Ui.fileFor(Ui.popups[next++]), Component.Asynchronous))
    }

    FocusScope {
        id: everything

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (!host.page || host.page.closeOnEscape)
                Ui.close();
        }

        Item {
            id: barStrip

            width: parent.width
            height: Theme.barZone
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Ui.close()
        }

        Item {
            id: frame

            readonly property bool flatLeft: host.placement === "left" || host.placement === "wide"
            readonly property bool flatRight: host.placement === "right" || host.placement === "wide"

            x: host.target.x
            y: host.target.y
            width: host.target.width
            height: host.target.height
            opacity: host.reveal
            scale: 0.96 + 0.04 * host.reveal

            Behavior on x {
                enabled: host.morphing
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: host.morphing
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: host.morphing
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                enabled: host.morphing
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }

            RectangularShadow {
                anchors.fill: parent
                radius: Theme.radiusLarge
                blur: Theme.px(48)
                offset.y: Theme.px(12)
                color: Theme.shadow
            }

            // Swallow clicks on the popup's own background.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                onWheel: wheel => wheel.accepted = true
            }

            ClippingRectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.base, 0.95)
                border.width: 1
                border.color: Theme.border
                topLeftRadius: frame.flatLeft ? 0 : Theme.radiusLarge
                bottomLeftRadius: frame.flatLeft ? 0 : Theme.radiusLarge
                topRightRadius: frame.flatRight ? 0 : Theme.radiusLarge
                bottomRightRadius: frame.flatRight ? 0 : Theme.radiusLarge

                // Pages keep their final size and stay centred while the frame morphs around them.
                Item {
                    id: pages

                    anchors.centerIn: parent
                    width: host.target.width
                    height: host.target.height
                }
            }
        }
    }

    // Cross-fade between the leaving and the arriving popup.
    ParallelAnimation {
        id: swap

        NumberAnimation { target: host.page; property: "opacity"; to: 1; duration: 210; easing.type: Easing.OutCubic }
        NumberAnimation { target: host.page; property: "scale"; from: 0.98; to: 1; duration: 210; easing.type: Easing.OutCubic }
        NumberAnimation { target: host.leaving; property: "opacity"; to: 0; duration: 140 }
        onFinished: {
            if (host.leaving)
                host.leaving.destroy();
            host.leaving = null;
        }
    }

    // Every page fills the pages area.
    onPageChanged: {
        if (page)
            page.anchors.fill = pages;
    }
}
