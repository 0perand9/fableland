import QtQuick
import Quickshell
import qs.core

// The quick-actions panel of one screen: where it is docked, how far out it
// is, and the windows that show it. Three one-pixel sensors watch the edges;
// the panel and the drawing overlay are only built once they are first used.
Scope {
    id: root

    required property var modelData
    readonly property var screen: modelData

    // The strip's buttons. An action with a `view` opens that module beside the strip.
    readonly property var actions: [
        { id: "draw", icon: Icons.draw },
        { id: "system", icon: Icons.speedometer, view: "SystemUsage.qml" },
        { id: "timers", icon: Icons.timer, view: "Timers.qml" }
    ]
    readonly property var modules: actions.filter(action => action.view).map(action => action.id)

    // Docked on `edge` (left | right | bottom), around `along`: the pointer's position on that edge.
    property string edge: "left"
    property real along: screen.height / 2
    // How far out the panel is: hidden → handle → strip (the action buttons) → module (one open beside them).
    property string stage: "hidden"
    // The module of the "module" stage; remembered for the next time.
    property string module: modules[0]
    // A pinned panel stays out when the pointer leaves it.
    property bool pinned: false
    // The annotation overlay is up.
    property bool drawing: false

    // Reported by the windows: the pointer is on an edge sensor / over the panel.
    property bool edgeTouched: false
    property bool panelHovered: false
    readonly property bool attended: edgeTouched || panelHovered

    // ── the pointer on an edge ──

    function touch(edge, along) {
        edgeTouched = true;
        rest.edge = edge;
        rest.along = along;
        // The handle follows the pointer along its edge; anything more waits until the pointer rests.
        if (stage === "handle" && edge === root.edge)
            root.along = along;
        else if (!rest.running)
            rest.start();
    }

    function untouch() {
        edgeTouched = false;
        rest.stop();
    }

    // The pointer rested on an edge: bring the handle there. A panel that is
    // further out stays where it is, unless another edge is asked for.
    function summon(edge, along) {
        const settled = stage === "strip" || stage === "module";
        if (settled && (pinned || edge === root.edge))
            return;
        root.edge = edge;
        root.along = along;
        stage = "handle";
    }

    // ── the panel ──

    function open(module) {
        if (modules.indexOf(module) < 0)
            return;
        root.module = module;
        stage = "module";
    }

    // A strip button: open its module, or close the one that is showing.
    function toggle(module) {
        if (stage === "module" && module === root.module)
            stage = "strip";
        else
            open(module);
    }

    function cycle(step) {
        const count = modules.length;
        open(modules[(modules.indexOf(module) + step + count) % count]);
    }

    // One step back in: module → strip → hidden.
    function back() {
        stage = stage === "module" ? "strip" : "hidden";
    }

    function hide() {
        stage = "hidden";
        pinned = false;
    }

    function draw() {
        drawing = true;
        // The overlay covers the panel; only a pinned one is still there afterwards.
        if (!pinned)
            hide();
    }

    // `fable open|toggle quick [draw|system|timers]`, and the dev preview.
    function command(action, what) {
        const toggling = action === "toggle";
        if (what === "draw") {
            if (toggling && drawing)
                drawing = false;
            else
                draw();
        } else if (modules.indexOf(what) >= 0) {
            if (toggling && stage === "module" && what === module)
                hide();
            else
                open(what);
        } else if (toggling && stage !== "hidden") {
            hide();
        } else if (stage === "hidden" || stage === "handle") {
            stage = "strip";
        }
    }

    onAttendedChanged: attended ? linger.stop() : linger.restart()
    onPinnedChanged: {
        if (!pinned && !attended)
            linger.restart();
    }
    onStageChanged: {
        if (stage !== "hidden")
            panel.active = true;
    }
    onDrawingChanged: {
        if (drawing)
            overlay.active = true;
    }
    Component.onCompleted: {
        const [target, what] = Ui.dev.split(":");
        if (target === "quick" && screen === Quickshell.screens[0])
            command("open", what ?? "");
    }

    Connections {
        target: Ui

        function onOverlay(name, action, arg) {
            if (name === "quick" && root.screen === Ui.focusedScreen)
                root.command(action, arg);
        }
    }

    // How long the pointer must rest on an edge before the handle appears,
    // so that merely crossing to the next monitor does not summon it.
    Timer {
        id: rest

        property string edge: ""
        property real along: 0

        interval: 300
        onTriggered: root.summon(edge, along)
    }

    // The pointer has left: the handle goes at once, the panel after a moment.
    Timer {
        id: linger

        interval: root.stage === "handle" ? 250 : 800
        onTriggered: {
            if (!root.pinned)
                root.hide();
        }
    }

    EdgeSensor {
        dock: root
        edge: "left"
    }

    EdgeSensor {
        dock: root
        edge: "right"
    }

    EdgeSensor {
        dock: root
        edge: "bottom"
    }

    LazyLoader {
        id: panel

        Panel {
            dock: root
        }
    }

    LazyLoader {
        id: overlay

        DrawOverlay {
            dock: root
        }
    }
}
