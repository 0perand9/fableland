import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.overlays.capture

// Choosing what to capture. The daemon announces a capture with a `capture`
// event — a frozen frame of a monitor to cut a screenshot from, or a request
// to mark an area for recording — and this overlay answers with the selection.
Scope {
    id: root

    // The capture being served (or the one served last): the data of the `capture` event.
    property var request: ({})
    // The overlay is up.
    property bool selecting: false
    // The area last used on each monitor, offered again the next time.
    property var remembered: ({})

    readonly property var actions: [
        { key: "copy", label: "Copy", icon: Icons.copy, tool: "screenshot" },
        { key: "edit", label: "Edit", icon: Icons.edit, tool: "edit" },
        { key: "ocr", label: "Text", icon: Icons.ocr, tool: "ocr" },
        { key: "qr", label: "QR", icon: Icons.qr, tool: "qr" }
    ]
    readonly property var sounds: [
        { key: "none", label: "Silent", icon: Icons.volumeOff },
        { key: "desktop", label: "Desktop", icon: Icons.volumeHigh },
        { key: "mic", label: "Mic", icon: Icons.mic }
    ]

    function open(request) {
        root.request = request;
        selecting = true;
    }

    function cancel() {
        selecting = false;
        Daemon.send("capture.cancel");
    }

    function remember(area) {
        // A copy: the rectangle handed in belongs to an overlay that is about to go.
        remembered[request.monitor] = Qt.rect(area.x, area.y, area.width, area.height);
    }

    // An area of the overlay in whole units, as the daemon wants it.
    function geometry(area) {
        return { x: Math.round(area.x), y: Math.round(area.y), w: Math.round(area.width), h: Math.round(area.height) };
    }

    function shoot(area, viewWidth, action) {
        Daemon.send("capture.shot", Object.assign({ viewWidth: viewWidth, action: action }, geometry(area)));
        selecting = false;
    }

    function record(area, audio) {
        afterClosing.send("capture.record", Object.assign({ monitor: request.monitor, audio: audio }, geometry(area)));
        selecting = false;
    }

    // Start over as a recording instead of a screenshot, or the other way round.
    function switchMode() {
        Daemon.send("capture.cancel");
        if (request.mode === "record")
            afterClosing.send("capture.start", { mode: "region" });
        else
            Daemon.send("capture.start", { mode: "record" });
        selecting = false;
    }

    // Development preview (FABLE_DEV_OPEN=capture or capture:record): as if the daemon had asked.
    function preview() {
        const mode = { "capture": "image", "capture:record": "record" }[Ui.dev];
        if (mode && Daemon.ready)
            open({ mode: mode, action: "copy", monitor: Quickshell.screens[0]?.name ?? "", image: Daemon.wallpaper.current.image ?? "", stamp: Date.now() });
    }

    Component.onCompleted: preview()

    Connections {
        target: Daemon

        function onEvent(name, data) {
            if (name !== "capture")
                return;
            // The same key again calls the selection off, and a locked session captures nothing.
            if (root.selecting || Ui.locked)
                root.cancel();
            else
                root.open(data);
        }

        // Without the daemon there is nobody to hand a selection to.
        function onConnectedChanged() {
            if (!Daemon.connected)
                root.selecting = false;
        }

        function onReadyChanged() {
            root.preview();
        }
    }

    Connections {
        target: Ui

        function onLockedChanged() {
            if (Ui.locked && root.selecting)
                root.cancel();
        }
    }

    // Calls that make the daemon look at the screen (start recording, grab a
    // frame) go out once the overlay is off it.
    Timer {
        id: afterClosing

        property var pending: null

        function send(method, params) {
            pending = { method: method, params: params };
            restart();
        }

        interval: 150
        onTriggered: Daemon.send(pending.method, pending.params)
    }

    LazyLoader {
        active: root.selecting

        PanelWindow {
            id: overlay

            readonly property bool recording: root.request.mode === "record"
            readonly property color hue: recording ? Theme.red : Theme.accent
            readonly property var choices: recording ? root.sounds : root.actions.filter(action => Daemon.capture.tools[action.tool])
            // The key of the picked choice: what to do with the screenshot, or the sound to record.
            property string choice: ""
            // The other kind of capture is available too.
            readonly property bool canSwitchMode: !!Daemon.capture.tools[recording ? "screenshot" : "record"]
            // Real pixels per unit of the overlay.
            readonly property real pixelRatio: {
                if (recording)
                    return Daemon.monitors.find(m => m.name === root.request.monitor)?.scale ?? 1;
                return frozen.status === Image.Ready && width > 0 ? frozen.implicitWidth / width : 1;
            }

            function confirm() {
                if (selection.exists)
                    root.remember(selection.area);
                // Without a selection, the whole screen.
                const area = selection.exists ? selection.area : Qt.rect(0, 0, width, height);
                if (recording)
                    root.record(area, choice);
                else
                    root.shoot(area, width, choice);
            }

            // The area comes along to the other mode.
            function switchMode() {
                if (!canSwitchMode)
                    return;
                if (selection.exists)
                    root.remember(selection.area);
                root.switchMode();
            }

            screen: Ui.screenNamed(root.request.monitor ?? "")
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "fableland-capture"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Component.onCompleted: {
                choice = recording ? Daemon.setting("capture.audio", "desktop") : (root.request.action ?? "copy");
                selection.set(root.remembered[root.request.monitor] ?? Qt.rect(0, 0, 0, 0));
                view.gliding = true;
            }

            // The frozen frame the screenshot is cut from. Every frame is written
            // to the same file; the stamp makes each one a new image to Qt.
            Image {
                id: frozen

                anchors.fill: parent
                visible: !overlay.recording
                source: overlay.recording ? "" : Fmt.file(root.request.image ?? "") + "?" + root.request.stamp
                cache: false
                asynchronous: true
            }

            Selection {
                id: selection

                // The overlay covers its screen, and the screen's size is known
                // before the window has been given its own.
                boundsWidth: overlay.screen?.width ?? 0
                boundsHeight: overlay.screen?.height ?? 0
            }

            SelectionView {
                id: view

                anchors.fill: parent
                focus: true
                selection: selection
                hue: overlay.hue
                pixelRatio: overlay.pixelRatio
                labelInside: toolbar.above
                hint: (overlay.recording ? "Drag over the area to record" : "Drag over the area to capture") + "  ·  Enter takes the whole screen  ·  Esc cancels"
                onCancelled: root.cancel()
                Keys.onPressed: event => {
                    const step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
                    switch (event.key) {
                    case Qt.Key_Escape: root.cancel(); break;
                    case Qt.Key_Return: case Qt.Key_Enter: overlay.confirm(); break;
                    case Qt.Key_Tab: overlay.switchMode(); break;
                    case Qt.Key_F11: case Qt.Key_F: selection.toggleFull(); break;
                    case Qt.Key_Left: selection.nudge(-step, 0); break;
                    case Qt.Key_Right: selection.nudge(step, 0); break;
                    case Qt.Key_Up: selection.nudge(0, -step); break;
                    case Qt.Key_Down: selection.nudge(0, step); break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }

            Toolbar {
                id: toolbar

                readonly property real gap: Theme.px(14)
                readonly property real spotBelow: selection.y + selection.height + gap
                readonly property real spotAbove: selection.y - height - gap
                readonly property bool below: spotBelow + height + gap <= overlay.height
                readonly property bool above: !below && spotAbove >= gap

                // Under the selection, else over it, else on top of it at the bottom of the screen.
                x: Math.max(gap, Math.min(overlay.width - width - gap, selection.x + (selection.width - width) / 2))
                y: below ? spotBelow : above ? spotAbove : overlay.height - height - gap
                visible: opacity > 0
                opacity: selection.exists && !selection.dragging ? 1 : 0
                recording: overlay.recording
                canSwitchMode: overlay.canSwitchMode
                choices: overlay.choices
                choice: overlay.choice
                full: selection.full
                hue: overlay.hue
                onModeSwitched: overlay.switchMode()
                onChosen: key => overlay.choice = key
                onFullToggled: selection.toggleFull()
                onConfirmed: overlay.confirm()
                onCancelled: root.cancel()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.fast }
                }
            }
        }
    }
}
