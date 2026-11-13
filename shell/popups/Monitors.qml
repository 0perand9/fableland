import QtQuick
import qs.core
import qs.widgets
import qs.popups.monitors
import "monitors/layout.js" as Layout

// The display settings: arrange the monitors by dragging them and choose each
// one's mode, scale and rotation. Edits live in a draft — nothing changes on
// screen until Apply — and an applied layout has to be confirmed, or the
// previous one comes back. `fable toggle monitors <name>` selects a monitor.
PopupPage {
    id: page

    readonly property var live: Daemon.monitors
    // The daemon's state as a layout (what Revert returns to) and the layout being edited.
    property var base: []
    property var draft: []
    readonly property bool dirty: !Layout.same(draft, base)
    // Monitor names; replaced only when a monitor comes or goes, so that the tabs survive edits.
    property var names: []

    property string selectedName: ""
    readonly property var selected: draft.find(m => m.name === selectedName) ?? null
    readonly property var selectedLive: live.find(m => m.name === selectedName) ?? null
    readonly property var resolutions: selectedLive ? Layout.resolutions(selectedLive) : []
    readonly property string resolutionKey: selected ? selected.width + "x" + selected.height : ""
    readonly property var rates: resolutions.find(entry => entry.key === resolutionKey)?.rates ?? []

    // The section the arrow keys act on: 0 resolution, 1 refresh rate, 2 scale,
    // 3 rotation, 4 HDR (only on a monitor that can show it).
    property int section: 0
    readonly property int sections: selected?.hdr !== undefined ? 5 : 4

    // The request on its way to the daemon; `abandoned` tells its reply that the popup has closed.
    property var request: null
    property string failure: ""
    // After Apply: the new layout is on screen and waits to be kept, while
    // `patience` runs from 1 to 0; `fallback` is the layout to return to.
    property bool confirming: false
    property var fallback: []
    property real patience: 1
    readonly property int graceSeconds: 15

    property bool identifying: false

    // Take over what the daemon reports. Unapplied edits survive it, unless
    // they were just applied or a monitor came or went.
    function adopt() {
        const next = Layout.seed(live);
        const keepEdits = dirty && !request && !confirming && Layout.sameNames(draft, next);
        base = next;
        if (!keepEdits)
            draft = next;
        const nextNames = next.map(m => m.name);
        if (nextNames.join() !== names.join())
            names = nextNames;
        if (names.indexOf(selectedName) < 0)
            selectedName = (live.find(m => m.focused) ?? live[0])?.name ?? "";
    }

    // Change the selected monitor; the others close up around its new size.
    function edit(changes) {
        if (!selected)
            return;
        failure = "";
        draft = Layout.settle(draft.map(m => m.name === selectedName ? Object.assign({}, m, changes) : m), selectedName);
    }

    function setResolution(entry) {
        // Stay as close as the new resolution allows to the rate and scale in use.
        edit({
            width: entry.width,
            height: entry.height,
            refreshRate: entry.rates[Layout.nearestRate(entry.rates, selected.refreshRate)],
            scale: Layout.cleanScale(entry.width, entry.height, selected.scale)
        });
    }

    function selectNext(by) {
        if (names.length > 0)
            selectedName = names[(names.indexOf(selectedName) + by + names.length) % names.length];
    }

    // The arrow keys: change the value of the current section.
    function nudge(dx, dy) {
        if (!selected)
            return;
        switch (section) {
        case 0: modes.step(dx + 2 * dy); break;
        case 1: tuning.setRate(tuning.rateAt + dx); break;
        case 2: tuning.stepScale(dx - dy); break;
        case 3: tuning.setTurn(tuning.turn + dx); break;
        case 4: if (dx !== 0) edit({ hdr: dx > 0 }); break;
        }
    }

    function apply() {
        if (!dirty || request)
            return;
        const ticket = { abandoned: false }, before = Layout.request(base);
        request = ticket;
        failure = "";
        Daemon.call("hypr.applyMonitors", { monitors: Layout.request(draft) }, (result, error) => {
            if (ticket.abandoned)
                return;
            page.request = null;
            if (error) {
                page.failure = error;
                return;
            }
            page.fallback = before;
            page.confirming = true;
        });
    }

    function goBack() {
        confirming = false;
        Daemon.send("hypr.applyMonitors", { monitors: fallback });
    }

    implicitWidth: Theme.px(800)
    implicitHeight: Theme.px(720)

    onLiveChanged: adopt()
    onSectionsChanged: section = Math.min(section, sections - 1)
    Component.onCompleted: {
        adopt();
        if (names.indexOf(arg) >= 0)
            selectedName = arg;
    }
    Component.onDestruction: {
        if (request)
            request.abandoned = true;
    }

    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Tab: ctrl ? selectNext(1) : section = (section + 1) % sections; break;
        case Qt.Key_Backtab: ctrl ? selectNext(-1) : section = (section + sections - 1) % sections; break;
        case Qt.Key_Left: nudge(-1, 0); break;
        case Qt.Key_Right: nudge(1, 0); break;
        case Qt.Key_Up: nudge(0, -1); break;
        case Qt.Key_Down: nudge(0, 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: confirming ? confirming = false : apply(); break;
        default: return;
        }
        event.accepted = true;
    }

    NumberAnimation on patience {
        from: 1
        to: 0
        duration: page.graceSeconds * 1000
        running: page.confirming
        // Nobody confirmed: the new layout may well be unusable.
        onFinished: page.goBack()
    }

    Timer {
        interval: 3000
        running: page.identifying
        onTriggered: page.identifying = false
    }

    Identify {
        active: page.identifying
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue, Theme.mauve]
    }

    // ── header ──
    Row {
        id: header

        x: Theme.px(24)
        y: Theme.px(22)
        spacing: Theme.px(12)

        Rectangle {
            width: Theme.px(36)
            height: Theme.px(36)
            radius: Theme.px(10)
            color: Theme.accent

            Icon {
                anchors.centerIn: parent
                text: page.names.length > 1 ? Icons.monitors : Icons.monitor
                size: 19
                color: Theme.accentText
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Txt {
                text: "Displays"
                size: 16
                bold: true
            }

            Txt {
                text: page.names.length > 1 ? "Drag a monitor to where it stands on your desk" : page.names.length === 1 ? "One monitor connected" : "No monitor found"
                size: 11
                color: Theme.subtext
            }
        }
    }

    Btn {
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(24)
        anchors.verticalCenter: header.verticalCenter
        kind: "flat"
        icon: Icons.eye
        text: "Identify"
        onClicked: page.identifying = true
    }

    // ── arrangement ──
    Card {
        id: canvas

        anchors.top: header.bottom
        anchors.topMargin: Theme.px(12)
        x: Theme.px(24)
        width: parent.width - 2 * x
        height: Theme.px(204)
        color: Theme.alpha(Theme.crust, 0.5)

        Arrangement {
            anchors.fill: parent
            monitors: page.draft
            selected: page.selectedName
            onPicked: name => page.selectedName = name
            onMoved: (name, x, y) => {
                page.failure = "";
                page.draft = page.draft.map(m => m.name === name ? Object.assign({}, m, { x: x, y: y }) : m);
            }
            onDropped: name => page.draft = Layout.settle(page.draft, name)
        }
    }

    // ── which monitor ──
    Tabs {
        id: picker

        anchors.top: canvas.bottom
        anchors.topMargin: Theme.px(12)
        x: Theme.px(24)
        width: visible ? Math.min(Theme.px(150) * page.names.length, Theme.px(400)) : 0
        implicitHeight: Theme.px(38)
        visible: page.names.length > 1
        // What people call their monitors, not the connectors they are plugged into.
        model: page.names.map(name => page.live.find(m => m.name === name)?.model || name)
        current: page.names.indexOf(page.selectedName)
        onSelected: index => page.selectedName = page.names[index]
    }

    Column {
        anchors.left: picker.right
        anchors.leftMargin: picker.visible ? Theme.px(16) : 0
        anchors.right: canvas.right
        anchors.verticalCenter: picker.verticalCenter

        Txt {
            width: parent.width
            text: page.selectedLive ? page.selectedLive.make + " " + page.selectedLive.model : ""
            size: 13
            bold: true
        }

        Txt {
            width: parent.width
            text: page.selected ? page.selectedName + " · at " + page.selected.x + ", " + page.selected.y : ""
            size: 11
            color: Theme.subtext
        }
    }

    // ── settings of the selected monitor ──
    Card {
        id: modeCard

        anchors.top: picker.bottom
        anchors.topMargin: Theme.px(12)
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.px(14)
        x: Theme.px(24)
        width: (parent.width - 2 * x - Theme.px(12)) / 2

        Section {
            anchors.fill: parent
            anchors.margins: Theme.px(14)
            title: "Resolution"
            value: page.selected ? page.selected.width + " × " + page.selected.height : ""
            current: page.section === 0

            ModeGrid {
                id: modes

                // The grid ends with the gap after its last column: let that hang over the edge.
                width: parent.width + gap
                height: modeCard.height - Theme.px(50)
                resolutions: page.resolutions
                current: page.resolutionKey
                onChosen: resolution => {
                    page.section = 0;
                    page.setResolution(resolution);
                }
            }
        }
    }

    Card {
        anchors.top: modeCard.top
        anchors.bottom: modeCard.bottom
        anchors.left: modeCard.right
        anchors.leftMargin: Theme.px(12)
        anchors.right: canvas.right

        Tuning {
            id: tuning

            x: Theme.px(14)
            y: Theme.px(14)
            width: parent.width - 2 * x
            monitor: page.selected
            rates: page.rates
            section: page.section
            onEdited: (section, changes) => {
                page.section = section;
                page.edit(changes);
            }
        }
    }

    // ── footer ──
    ApplyBar {
        id: footer

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(24)
        x: Theme.px(24)
        width: parent.width - 2 * x
        dirty: page.dirty
        busy: page.request !== null
        failure: page.failure
        confirming: page.confirming
        patience: page.patience
        graceSeconds: page.graceSeconds
        several: page.names.length > 1
        onApplyClicked: page.apply()
        onRevertClicked: page.draft = page.base
        onKeepClicked: page.confirming = false
        onGoBackClicked: page.goBack()
    }
}
