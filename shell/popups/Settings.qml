import QtQuick
import qs.core
import qs.widgets
import qs.popups.settings

// The settings sidebar: every setting of docs/PROTOCOL.md, one page per subject.
// The pages are settings/<Key>Page.qml, composed from the row components next
// to them. Typing in the search field shows the matching rows of all pages.
PopupPage {
    id: page

    // `key` names the page's file and is the argument of `fable toggle settings <key>`;
    // `short` stands in on the rail for a title that does not fit there. A page
    // about `features` (Daemon.has) is left out while all of them are off.
    readonly property var corePages: [
        { key: "general", title: "General", icon: Icons.tune },
        { key: "appearance", title: "Appearance", icon: Icons.palette },
        { key: "weather", title: "Weather", icon: Icons.weatherPartlyDay, features: ["weather"] },
        { key: "keyboard", title: "Keyboard", icon: Icons.keyboard },
        { key: "keybinds", title: "Keybinds", icon: Icons.keybinds },
        { key: "startup", title: "Startup", icon: Icons.rocket },
        { key: "monitors", title: "Monitors", icon: Icons.monitor },
        { key: "notifications", title: "Notifications", short: "Alerts", icon: Icons.bell, features: ["notifications"] },
        { key: "focus", title: "Focus", icon: Icons.target, features: ["focus"] },
        { key: "lock", title: "Lock & idle", short: "Lock", icon: Icons.lock },
        { key: "capture", title: "Capture & clipboard", short: "Capture", icon: Icons.screenshot, features: ["capture", "clipboard"] },
        { key: "calendar", title: "Calendar", icon: Icons.calendar },
        { key: "updates", title: "Updates", icon: Icons.update, features: ["updates"] },
        { key: "about", title: "About", icon: Icons.info }
    ].filter(entry => !entry.features || entry.features.some(feature => Daemon.has(feature)))
    // The plugins' pages go before About; theirs name their file.
    readonly property var pages: corePages.slice(0, -1).concat(Plugins.settingsPages, corePages.slice(-1))
    property int current: indexOf(arg)

    readonly property bool searching: Search.active
    // Whether the search has found nothing, once every page has been looked at.
    readonly property bool nothingFound: {
        if (!searching)
            return false;
        for (const slot of stack.children)
            if (slot.matched || slot.loading)
                return false;
        return true;
    }

    function indexOf(key) {
        return Math.max(0, pages.findIndex(entry => entry.key === key));
    }

    // Leaves the search, if any: picking a page shows that page.
    function show(index) {
        // A row that has the keyboard focus is about to go; the search field takes over.
        if (within(stack, focused))
            search.forceActiveFocus();
        search.text = "";
        current = index;
    }

    function scrollBy(distance) {
        scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + distance));
    }

    // ── keyboard ──
    // Typing searches. The arrow keys move the focus over the rows, where Enter
    // acts and Left/Right change the value (see SettingRow). Tab changes the page.
    readonly property Item focused: Window.activeFocusItem

    function within(ancestor, item) {
        for (let it = item; it; it = it.parent)
            if (it === ancestor)
                return true;
        return false;
    }

    // The row (or list entry) an item is part of, if any.
    function rowAround(item) {
        for (let it = item.parent; it && it !== stack; it = it.parent)
            if (it.focusStop === true)
                return it;
        return null;
    }

    // The rows and list entries on show, from top to bottom. (Not Qt's own focus
    // chain: that follows the order of creation, which in a scrolled list is not
    // the order on screen — and it would claim Tab for itself.)
    function focusStops() {
        const stops = [];
        const collect = item => {
            if (!item.visible)
                return;
            if (item.focusStop === true)
                stops.push(item);
            for (const child of item.children)
                collect(child);
        };
        collect(stack);
        const top = item => item.mapToItem(stack, 0, 0).y;
        return stops.sort((a, b) => top(a) - top(b));
    }

    // Moves the focus to the next or previous row; past either end it returns to the search field.
    function step(forward) {
        const stops = focusStops();
        let to;
        if (!within(stack, focused)) {
            to = forward ? stops[0] : undefined;
        } else {
            const row = focused.focusStop === true ? focused : rowAround(focused);
            const at = stops.indexOf(row);
            // From a field inside a row, up is the row itself.
            to = stops[forward ? at + 1 : row === focused ? at - 1 : at];
        }
        (to ?? search).forceActiveFocus();
    }

    implicitWidth: Theme.px(450)
    implicitHeight: Theme.px(900)
    placement: "left"

    onArgChanged: current = indexOf(arg)
    onCurrentChanged: scroll.contentY = 0
    onSearchingChanged: scroll.contentY = 0
    Component.onCompleted: Search.query = ""
    // Whatever has the keyboard focus stays in view.
    onFocusedChanged: {
        if (!within(stack, focused))
            return;
        const margin = Theme.px(12);
        const top = focused.mapToItem(stack, 0, 0).y - margin;
        const bottom = top + focused.height + 2 * margin;
        if (top < scroll.contentY)
            scrollBy(top - scroll.contentY);
        else if (bottom > scroll.contentY + scroll.height)
            scrollBy(bottom - scroll.contentY - scroll.height);
    }

    // Escape steps outwards: from a field to its row, from a row to the search
    // field, then out of the search — and only then does it close the sidebar.
    Keys.onEscapePressed: event => {
        if (within(stack, focused))
            (rowAround(focused) ?? search).forceActiveFocus();
        else if (searching)
            search.text = "";
        else
            event.accepted = false;
    }
    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const typing = focused instanceof TextInput && focused !== search.input;
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            // Tab walks through the pages, as it did in the old shell. Inside a text field
            // other than the search it takes Ctrl, so that the field keeps the plain key.
            if (typing && !ctrl)
                return;
            show((current + (event.key === Qt.Key_Tab ? 1 : pages.length - 1)) % pages.length);
        } else if (event.key === Qt.Key_Down) {
            step(true);
        } else if (event.key === Qt.Key_Up) {
            step(false);
        } else if (event.key === Qt.Key_PageDown) {
            scrollBy(scroll.height * 0.8);
        } else if (event.key === Qt.Key_PageUp) {
            scrollBy(-scroll.height * 0.8);
        } else if ((ctrl && event.key === Qt.Key_F) || event.key === Qt.Key_Slash) {
            search.forceActiveFocus();
            search.input.selectAll();
        } else if (event.text >= " " && event.text !== "\x7f" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            // Typing anywhere but in a field continues in the search field.
            search.text += event.text;
            search.forceActiveFocus();
        } else {
            return;
        }
        event.accepted = true;
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue, Theme.mauve]
        strength: 0.1
    }

    // Clicking the background takes the focus out of a text field, which commits it.
    MouseArea {
        anchors.fill: parent
        onPressed: nothing.forceActiveFocus()
    }

    Item {
        id: nothing
    }

    Txt {
        id: heading

        x: Theme.px(20)
        y: Theme.px(18)
        text: "Settings"
        size: 22
        bold: true
    }

    IconBtn {
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(14)
        anchors.verticalCenter: heading.verticalCenter
        icon: Icons.close
        iconColor: Theme.subtext
        onClicked: page.close()
    }

    Field {
        id: search

        anchors.top: heading.bottom
        anchors.topMargin: Theme.px(12)
        x: Theme.px(16)
        width: parent.width - 2 * x
        implicitHeight: Theme.px(40)
        focus: true
        size: 13
        icon: Icons.search
        placeholder: "Search settings"
        onTextChanged: Search.query = text
        // Enter goes on to the first row (of the matches, in a search).
        onAccepted: page.step(true)
    }

    Rail {
        id: rail

        anchors.top: search.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(14)
        anchors.bottomMargin: Theme.px(12)
        x: Theme.px(8)
        pages: page.pages
        current: page.searching ? -1 : page.current
        onSelected: index => page.show(index)
    }

    Txt {
        anchors.centerIn: scroll
        visible: page.nothingFound
        width: scroll.width - Theme.px(40)
        horizontalAlignment: Text.AlignHCenter
        text: "No setting matches “" + Search.query.trim() + "”"
        color: Theme.dim
        size: 13
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    Scroll {
        id: scroll

        anchors.top: rail.top
        anchors.bottom: parent.bottom
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.leftMargin: Theme.px(10)
        anchors.rightMargin: Theme.px(4)

        MouseArea {
            width: scroll.width
            height: Math.max(scroll.height, stack.height)
            onPressed: nothing.forceActiveFocus()
        }

        Column {
            id: stack

            width: scroll.width - Theme.px(12)
            spacing: Theme.px(22)
            bottomPadding: Theme.px(24)

            Repeater {
                model: page.pages

                // One page: on show when it is the current one, or — in a search — when it has matches.
                Column {
                    id: slot

                    required property var modelData
                    required property int index
                    readonly property bool wanted: page.searching || index === page.current
                    readonly property bool loading: wanted && loader.status !== Loader.Ready
                    readonly property bool matched: loader.item !== null && loader.item.shown

                    width: stack.width
                    spacing: Theme.px(12)
                    visible: matched

                    // The page's name: a heading normally, a caption over its matches in a search.
                    Row {
                        x: Theme.px(4)
                        spacing: Theme.px(8)

                        Icon {
                            visible: page.searching
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.modelData.icon
                            size: 15
                            color: Theme.accent
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.modelData.title
                            size: page.searching ? 13 : 18
                            bold: true
                            color: page.searching ? Theme.accent : Theme.text
                        }
                    }

                    Loader {
                        id: loader

                        width: parent.width
                        active: slot.wanted
                        // A search loads all pages at once: spread that over a few frames.
                        asynchronous: page.searching
                        source: slot.modelData.file ?? Qt.resolvedUrl("settings/" + Fmt.capitalize(slot.modelData.key) + "Page.qml")
                    }

                    Binding {
                        target: loader.item
                        property: "title"
                        value: slot.modelData.title
                        when: loader.item !== null
                    }

                    Binding {
                        target: loader.item
                        property: "viewHeight"
                        value: scroll.height
                        when: loader.item !== null
                    }
                }
            }
        }
    }
}
