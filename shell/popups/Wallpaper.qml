import QtQuick
import qs.core
import qs.widgets
import qs.popups.wallpaper

// The wallpaper picker: the library as a carousel of slanted cards, filtered by
// colour, and an online search whose results are saved into the library when
// chosen. `fable toggle wallpaper <file name>` opens it on that wallpaper.
PopupPage {
    id: page

    readonly property var library: Daemon.wallpaper
    readonly property var online: Daemon.wallsearch
    readonly property string currentPath: library.current?.path ?? ""

    // "all", "video", one of the daemon's colour buckets, or "search" for the online results.
    property string filter: "all"
    readonly property bool searching: filter === "search"
    // Cards may yet come: the search is running, or thumbnails are being made.
    readonly property bool working: searching ? online.state === "running" : library.busy
    // What the carousel shows.
    readonly property var cards: {
        if (searching)
            return online.results;
        return filter === "all" ? library.items : library.items.filter(item => matches(item, filter));
    }
    // Wallpapers per filter.
    readonly property var counts: {
        const n = { all: library.items.length, video: 0 };
        for (const item of library.items) {
            if (item.video)
                n.video++;
            n[item.bucket] = (n[item.bucket] ?? 0) + 1;
        }
        return n;
    }

    // The focused card, and the entry that keeps the focus when the list changes under it.
    property int index: 0
    property string focusKey: ""
    readonly property var focused: cards[index] ?? null
    // Where to land in a filter entered by walking past the end of its neighbour: "first" or "last".
    property string landing: ""
    // The search result being saved into the library, and why the last one could not be.
    property var download: null
    property string problem: ""
    // The focused wallpaper colours the room.
    property color glow: focused?.color ?? Theme.surface1

    function matches(item, id) {
        return id === "video" ? item.video : item.bucket === id;
    }

    // Library items are told apart by path, search results by id.
    function keyOf(entry) {
        return entry.path ?? entry.id;
    }

    function indexOfKey(key) {
        return key === "" ? -1 : cards.findIndex(entry => keyOf(entry) === key);
    }

    // The library path of a wallpaper given by file name or by path ("" if there is none).
    function pathOf(name) {
        return library.items.find(item => item.name === name || item.path === name)?.path ?? "";
    }

    // The card that should have the focus in the list as it is now.
    function wantedIndex() {
        let at = indexOfKey(focusKey);
        if (at < 0 && landing !== "")
            at = landing === "last" ? cards.length - 1 : 0;
        if (at < 0 && !searching)
            at = indexOfKey(currentPath);
        return Math.max(0, at);
    }

    function focusCard(at) {
        if (at < 0 || at >= cards.length)
            return;
        index = at;
        focusKey = keyOf(cards[at]);
        problem = "";
    }

    function step(by) {
        const next = index + by;
        if (next >= 0 && next < cards.length) {
            focusCard(next);
            return;
        }
        if (searching)
            return;
        // Past either end the walk carries on in the next filter that has something.
        const order = bar.order, way = by > 0 ? 1 : -1;
        for (let at = order.indexOf(filter) + way; at >= 0 && at < order.length && order[at] !== "search"; at += way) {
            if ((counts[order[at]] ?? 0) === 0)
                continue;
            landing = way > 0 ? "first" : "last";
            focusKey = "";
            filter = order[at];
            return;
        }
    }

    function cycleFilter(by) {
        const order = bar.order;
        filter = order[(order.indexOf(filter) + by + order.length) % order.length];
    }

    // Bring the wallpaper that just went on screen into focus (it may have been set from elsewhere).
    function reveal(path) {
        if (searching || path === "")
            return;
        focusKey = path;
        const at = indexOfKey(path);
        if (at >= 0)
            index = at;
        else if (filter !== "all" && library.items.some(item => item.path === path))
            filter = "all";
    }

    function activate(at) {
        const entry = cards[at];
        if (!entry)
            return;
        focusCard(at);
        const target = outputs.outputs.length > 0 ? { outputs: outputs.outputs } : {};
        if (!searching) {
            Daemon.send("wallpaper.apply", Object.assign({ path: entry.path }, target));
            return;
        }
        if (download)
            return;
        // The reply may arrive after the picker has closed; the ticket says whether anyone still cares.
        const ticket = { id: entry.id, abandoned: false };
        download = ticket;
        Daemon.call("wallpaper.saveResult", Object.assign({ id: entry.id, apply: true }, target), (path, error) => {
            if (ticket.abandoned)
                return;
            page.download = null;
            page.problem = error ?? "";
        });
    }

    implicitHeight: Theme.px(650)
    placement: "wide"

    onCardsChanged: {
        // The list changed under the strip: keep the same entry in the middle, without travelling.
        const at = wantedIndex();
        landing = "";
        if (at !== index) {
            index = at;
            carousel.snap();
        }
    }
    onFilterChanged: {
        carousel.deal();
        if (!searching)
            carousel.forceActiveFocus();
    }
    onCurrentPathChanged: reveal(currentPath)
    onArgChanged: reveal(pathOf(arg))

    Behavior on glow {
        ColorAnimation { duration: Theme.slow }
    }

    Component.onCompleted: {
        focusKey = pathOf(arg) || currentPath;
        index = wantedIndex();
        carousel.snap();
        bar.query = online.query;
        // Files added to the folder since the last look show up.
        Daemon.send("wallpaper.rescan");
    }
    Component.onDestruction: {
        if (download)
            download.abandoned = true;
        if (online.state === "running")
            Daemon.send("wallpaper.searchStop");
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: step(-1); break;
        case Qt.Key_Right: step(1); break;
        case Qt.Key_Home: focusCard(0); break;
        case Qt.Key_End: focusCard(cards.length - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: activate(index); break;
        case Qt.Key_Tab: cycleFilter(1); break;
        case Qt.Key_Backtab: cycleFilter(-1); break;
        // Out of the search field, back to the cards.
        case Qt.Key_Down: carousel.forceActiveFocus(); break;
        case Qt.Key_Escape:
            if (schemes.open)
                schemes.open = false;
            else if (searching)
                filter = "all";
            else
                return;
            break;
        default:
            // Typing anywhere starts an online search (control characters and shortcuts are not typing).
            if (event.text.length !== 1 || event.text <= " " || event.text === "\x7f" || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                return;
            filter = "search";
            if (event.text !== "/")
                bar.type(event.text);
        }
        event.accepted = true;
    }

    // The wheel walks through the cards wherever the pointer is.
    WheelHandler {
        // Travel not yet turned into a step (120 is one notch).
        property real pending: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta;
            pending += Math.abs(delta.x) > Math.abs(delta.y) ? delta.x : delta.y;
            const notches = Math.trunc(pending / 120);
            if (notches === 0)
                return;
            pending -= notches * 120;
            page.step(-notches);
        }
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue, Theme.pink]
        strength: 0.1
    }

    Rectangle {
        anchors.fill: carousel
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0.15; color: Theme.alpha(page.glow, 0) }
            GradientStop { position: 0.5; color: Theme.alpha(page.glow, 0.22) }
            GradientStop { position: 0.85; color: Theme.alpha(page.glow, 0) }
        }
    }

    Carousel {
        id: carousel

        anchors.top: bar.bottom
        anchors.bottom: caption.top
        width: parent.width
        focus: true
        entries: page.cards
        index: page.index
        currentPath: page.currentPath
        busyId: page.download?.id ?? ""
        onPicked: index => page.focusCard(index)
        onActivated: index => page.activate(index)
    }

    EmptyNote {
        anchors.centerIn: carousel
        visible: page.cards.length === 0
        filter: page.filter
        working: page.working
    }

    // ── top row ──
    CycleButtons {
        x: Theme.px(24)
        y: bar.y
    }

    FilterBar {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(26)
        current: page.filter
        counts: page.counts
        searchRunning: page.online.state === "running"
        onSelected: id => page.filter = id
        onStopRequested: Daemon.send("wallpaper.searchStop")
        onSearchRequested: query => {
            if (query === "")
                return;
            page.focusKey = "";
            page.problem = "";
            Daemon.send("wallpaper.search", { query: query });
            carousel.forceActiveFocus();
        }
    }

    Row {
        id: options

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(24)
        y: bar.y
        spacing: Theme.px(8)

        OutputPicker {
            id: outputs
        }

        Pill {
            visible: page.library.tools.theme ?? false
            implicitWidth: implicitHeight

            IconBtn {
                anchors.centerIn: parent
                icon: Icons.palette
                size: 36
                iconColor: Theme.subtext
                active: schemes.open
                onClicked: schemes.open = !schemes.open
            }
        }
    }

    // ── bottom row ──
    Tally {
        x: Theme.px(28)
        anchors.verticalCenter: caption.verticalCenter
        searching: page.searching
        working: page.working
    }

    Caption {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(26)
        entry: page.focused
        searching: page.searching
        showing: page.focused !== null && page.focused.path === page.currentPath
        downloading: page.download !== null && page.download.id === page.focused?.id
        problem: page.problem
        place: (page.index + 1) + " / " + page.cards.length
    }

    Txt {
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(28)
        anchors.verticalCenter: caption.verticalCenter
        text: "←  →  browse    ↵  apply    Tab  filter    type to search online"
        size: 12
        color: Theme.dim
    }

    // ── palette menu ──
    MouseArea {
        anchors.fill: parent
        enabled: schemes.open
        onPressed: schemes.open = false
    }

    SchemeMenu {
        id: schemes

        anchors.top: options.bottom
        anchors.right: options.right
        anchors.topMargin: Theme.px(8)
    }
}
