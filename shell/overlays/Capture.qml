import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.overlays.capture

// Choosing what to capture. The daemon announces a capture with a `capture`
// event — frozen frames of the monitors to cut a screenshot from, or a request
// to mark an area for recording — and this overlay answers with the selection.
// It covers every monitor; the selection is on one of them at a time, the
// `active` one, which starts as the focused monitor and changes with a drag
// on another.
Scope {
    id: root

    // The capture being served (or the one served last): the data of the `capture` event.
    property var request: ({})
    // The overlay is up.
    property bool selecting: false
    // The monitor the selection is on, which has the keyboard and the toolbar.
    property string active: ""
    // The monitors to cover: those the request names that are connected.
    readonly property var covered: selecting ? (request.monitors ?? [request.monitor]).filter(name => Quickshell.screens.some(s => s.name === name)) : []
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
        active = request.monitor ?? "";
        selecting = true;
    }

    function cancel() {
        selecting = false;
        Daemon.send("capture.cancel");
    }

    function remember(area) {
        // A copy: the rectangle handed in belongs to an overlay that is about to go.
        remembered[active] = Qt.rect(area.x, area.y, area.width, area.height);
    }

    // An area of the overlay in whole units, as the daemon wants it.
    function geometry(area) {
        return { x: Math.round(area.x), y: Math.round(area.y), w: Math.round(area.width), h: Math.round(area.height) };
    }

    function shoot(area, viewWidth, action) {
        Daemon.send("capture.shot", Object.assign({ monitor: active, viewWidth: viewWidth, action: action }, geometry(area)));
        selecting = false;
    }

    function record(area, audio) {
        afterClosing.send("capture.record", Object.assign({ monitor: active, audio: audio }, geometry(area)));
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
        if (!mode || !Daemon.ready)
            return;
        const names = Quickshell.screens.map(s => s.name), images = {};
        for (const name of names)
            images[name] = Daemon.wallpaper.current.image ?? "";
        open({ mode: mode, action: "copy", monitor: names[0] ?? "", monitors: names, images: images, stamp: Date.now() });
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

    Variants {
        model: root.covered

        PanelWindow {
            id: overlay

            required property string modelData
            readonly property bool active: root.active === modelData

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
                    return Daemon.monitors.find(m => m.name === modelData)?.scale ?? 1;
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

            screen: Ui.screenNamed(modelData)
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
            WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            Component.onCompleted: {
                choice = recording ? Daemon.setting("capture.audio", "desktop") : (root.request.action ?? "copy");
                if (active)
                    selection.set(root.remembered[modelData] ?? Qt.rect(0, 0, 0, 0));
                view.gliding = true;
            }
            // One selection at a time: the monitor that loses it lets it go.
            onActiveChanged: {
                if (!active)
                    selection.set(Qt.rect(0, 0, 0, 0));
            }

            // The frozen frame the screenshot is cut from. Every frame is written
            // to the same file; the stamp makes each one a new image to Qt.
            Image {
                id: frozen

                anchors.fill: parent
                visible: !overlay.recording
                source: overlay.recording ? "" : Fmt.file(root.request.images?.[overlay.modelData] ?? "") + "?" + root.request.stamp
                cache: false
                asynchronous: true
            }

            Selection {
                id: selection

                // The overlay covers its screen, and the screen's size is known
                // before the window has been given its own.
                boundsWidth: overlay.screen?.width ?? 0
                boundsHeight: overlay.screen?.height ?? 0

                // A drag here takes the selection over from another monitor.
                onDraggingChanged: {
                    if (dragging)
                        root.active = overlay.modelData;
                }
            }

            SelectionView {
                id: view

                anchors.fill: parent
                focus: overlay.active
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
