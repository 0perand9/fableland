import QtQuick
import qs.core
import qs.widgets
import qs.popups.network

// Wi-Fi, Bluetooth and Ethernet as an orbital hub: the connection in use sits
// in the middle, and around it circle either the facts about it or everything
// in reach. `fable toggle network wifi|bt|eth` picks the side.
//
// Keys: Tab / Shift+Tab change the side, Left / Right walk the cards, Enter
// activates one, Delete forgets it.
PopupPage {
    id: page

    // The side chosen with the tabs; empty = the one the argument asks for.
    property string picked: ""
    readonly property string wanted: picked !== "" ? picked : arg === "bt" ? "bt" : arg === "eth" ? "eth" : "wifi"
    // The sides this machine has, in tab order.
    readonly property var sides: [ethernet, wifi, bluetooth].filter(side => side.present)
    readonly property Side side: sides.find(side => side.key === wanted) ?? sides[0] ?? nothing

    // The link in the hub; `focused` chooses among several (Bluetooth).
    property string focused: ""
    readonly property var link: side.links.find(link => link.key === focused) ?? side.links[0] ?? null
    readonly property bool linked: link !== null
    // With a link, its facts orbit the hub — unless the user asked for the peers.
    property bool wantFacts: true
    readonly property bool showFacts: linked && (wantFacts || side.peersTitle === "")

    // More peers than fit on the orbit are shown a page at a time.
    readonly property int capacity: 10
    property int pageIndex: 0
    readonly property int pageCount: side.peers.length <= capacity ? 1 : Math.ceil(side.peers.length / (capacity - 1))
    readonly property var shown: {
        if (showFacts)
            return link.facts;
        if (pageCount === 1)
            return side.peers;
        const size = capacity - 1, at = Math.min(pageIndex, pageCount - 1);
        const more = { key: "more", kind: "more", icon: Icons.dots, title: "More", note: "Page " + (at + 1) + " of " + pageCount, hint: "Next page" };
        return side.peers.slice(at * size, (at + 1) * size).concat([more]);
    }

    // SSID of the network waiting for its password.
    property string prompt: ""
    // Key of the card under the keyboard cursor, and of the fact just copied.
    property string cursor: ""
    property string copied: ""
    // Key of the card that was asked to be forgotten once, and will be if asked again.
    property string doomed: ""

    function pick(key) {
        if (key === side.key)
            return;
        picked = key;
        Daemon.send("misc.sound", { name: "switch" });
    }

    function stepSide(by) {
        if (sides.length > 1)
            pick(sides[(sides.indexOf(side) + by + sides.length) % sides.length].key);
    }

    function stepCursor(by) {
        const count = cards.rows.count;
        if (count === 0)
            return;
        let at = -1;
        for (let i = 0; i < count && at < 0; i++)
            if (cards.rows.get(i).key === cursor)
                at = i;
        cursor = cards.rows.get(at < 0 ? (by > 0 ? 0 : count - 1) : (at + by + count) % count).key;
    }

    function activate(card) {
        prompt = "";
        if (card.kind === "more") {
            pageIndex = (Math.min(pageIndex, pageCount - 1) + 1) % pageCount;
        } else if (card.kind === "fact") {
            if (!card.copy)
                return;
            Daemon.send("clipboard.copyText", { text: card.title });
            copied = card.key;
            forgetCopied.restart();
        } else if (card.linked) {
            focused = card.key;
            wantFacts = true;
        } else if (card.locked) {
            prompt = card.key;
        } else if (card.tone !== "busy") {
            side.connect(card.key);
        }
    }

    // Forgetting takes asking twice — two clicks on the bin, two presses of Delete.
    function forget(card) {
        if (!card.known)
            return;
        if (doomed !== card.key) {
            doomed = card.key;
            reprieve.restart();
            return;
        }
        doomed = "";
        side.forget(card.key);
    }

    // The card under the keyboard cursor, if it is still there.
    function cursorCard() {
        return cards.byKey[cursor] ?? null;
    }

    // Tab changes the side — or, as in the prompt, just backs out of it.
    function tab(by) {
        if (prompt !== "")
            prompt = "";
        else
            stepSide(by);
    }

    implicitWidth: Theme.px(900)
    implicitHeight: Theme.px(700)
    placement: "top-right"
    // Escape first leaves the password prompt.
    closeOnEscape: prompt === ""

    onArgChanged: picked = ""
    onCursorChanged: doomed = ""
    onSideChanged: {
        prompt = "";
        cursor = "";
        focused = "";
        pageIndex = 0;
        wantFacts = true;
    }
    // A fresh connection shows what it is.
    onLinkedChanged: {
        if (linked)
            wantFacts = true;
    }
    onPromptChanged: {
        if (prompt !== "")
            passwordPrompt.forceActiveFocus();
        else
            passwordPrompt.focus = false;
    }

    Keys.onTabPressed: tab(1)
    Keys.onBacktabPressed: tab(-1)
    Keys.onLeftPressed: stepCursor(-1)
    Keys.onRightPressed: stepCursor(1)
    Keys.onReturnPressed: cursorCard() && activate(cursorCard())
    Keys.onEnterPressed: cursorCard() && activate(cursorCard())
    Keys.onDeletePressed: cursorCard() && forget(cursorCard())

    EthernetSide {
        id: ethernet
    }

    WifiSide {
        id: wifi
    }

    BluetoothSide {
        id: bluetooth
    }

    // Stands in on a machine without any adapter: absent, off and empty.
    Side {
        id: nothing
    }

    // Scanning costs power and airtime: only for the side on show.
    Want {
        topic: "wifi"
        active: page.side === wifi && wifi.powered
    }

    Want {
        topic: "btscan"
        active: page.side === bluetooth && bluetooth.powered
    }

    KeyedModel {
        id: cards

        key: "key"
        source: page.shown
    }

    Timer {
        id: reprieve

        interval: 3000
        onTriggered: page.doomed = ""
    }

    Timer {
        id: forgetCopied

        interval: 1500
        onTriggered: page.copied = ""
    }

    Backdrop {
        anchors.fill: parent
        colors: [page.side.hue, Theme.accent, Theme.blue]
        strength: page.side.powered ? 0.16 : 0.07

        Behavior on strength {
            NumberAnimation { duration: Theme.slow }
        }
    }

    // ── the orbit: everything above the tab bar ──
    Item {
        width: parent.width
        height: parent.height - Theme.px(64)

        Orbit {
            id: radar

            anchors.fill: parent
            hue: page.side.hue
            opacity: page.side.powered ? 1 : 0.35

            Behavior on opacity {
                NumberAnimation { duration: Theme.slow }
            }
        }

        // The satellites; they step back while the prompt wants attention.
        Item {
            anchors.fill: parent
            opacity: !page.side.powered ? 0 : page.prompt !== "" ? 0.35 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }

            Repeater {
                model: cards.rows

                Item {
                    id: rider

                    required property string key
                    required property int index
                    readonly property var card: cards.byKey[key] ?? ({})
                    readonly property bool isFact: card.kind === "fact"

                    anchors.fill: parent
                    z: satellite.hovered ? 1 : 0

                    Tether {
                        anchors.fill: parent
                        visible: rider.isFact
                        from: radar.center
                        clearance: hub.width / 2 + Theme.px(12)
                        to: satellite.center
                        toSize: Qt.size(satellite.width + Theme.px(12), satellite.height + Theme.px(12))
                        hue: page.side.hue
                    }

                    Satellite {
                        id: satellite

                        orbit: radar
                        slot: rider.index
                        slots: cards.count
                        ring: rider.isFact ? 0 : rider.index % 2
                        icon: rider.card.icon ?? ""
                        title: rider.card.title ?? ""
                        fitTitle: rider.isFact
                        note: page.copied === rider.key ? "Copied" : (rider.card.note ?? "")
                        hint: rider.isFact ? (rider.card.copy && page.copied !== rider.key ? "Click to copy" : "") : (rider.card.hint ?? "")
                        tone: rider.card.tone ?? ""
                        hue: page.side.hue
                        interactive: !rider.isFact || !!rider.card.copy
                        selected: page.cursor === rider.key
                        actionIcon: rider.card.known ? Icons.trash : ""
                        actionNote: "Again to forget"
                        armed: page.doomed === rider.key
                        onClicked: page.activate(rider.card)
                        onActionClicked: page.forget(rider.card)
                    }
                }
            }
        }

        Hub {
            id: hub

            anchors.centerIn: radar
            shown: page.side.powered && page.prompt === ""
            link: page.link
            hue: page.side.hue
            idleIcon: page.side.icon
            idleText: page.side.idleText
            linkCount: page.side.links.length
            linkIndex: Math.max(0, page.side.links.indexOf(page.link))
            onDropRequested: page.side.disconnect(page.link.key)
            onStepRequested: {
                if (linkCount > 1)
                    page.focused = page.side.links[(linkIndex + 1) % linkCount].key;
            }
        }

        PasswordPrompt {
            id: passwordPrompt

            anchors.centerIn: radar
            shown: page.prompt !== ""
            ssid: page.prompt
            hue: page.side.hue
            onAccepted: password => {
                page.side.connect(page.prompt, password);
                page.prompt = "";
            }
            onCancelled: page.prompt = ""
        }

        Txt {
            anchors.centerIn: parent
            visible: page.sides.length === 0
            text: "No network adapters"
            color: Theme.dim
        }
    }

    SideTitle {
        x: Theme.px(24)
        y: Theme.px(22)
        visible: page.sides.length > 0
        side: page.side
    }

    // ── what orbits: the link's facts or the peers ──
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(24)
        y: Theme.px(24)
        spacing: Theme.px(8)
        visible: page.side.powered

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            visible: page.side.searching && !page.showFacts
            color: page.side.hue
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            visible: page.side.canRescan && !page.showFacts
            icon: Icons.refresh
            iconColor: Theme.subtext
            onClicked: {
                page.side.rescan();
                whirl.restart();
            }

            RotationAnimation on rotation {
                id: whirl

                running: false
                from: 0
                to: 360
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        Tabs {
            visible: page.linked && page.side.peersTitle !== ""
            width: Theme.px(230)
            height: Theme.px(36)
            model: [{ label: "Details", icon: Icons.info }, { label: page.side.peersTitle, icon: page.side.icon }]
            current: page.showFacts ? 0 : 1
            accentColor: page.side.hue
            size: 12
            onSelected: index => page.wantFacts = index === 0
        }
    }

    // ── the sides ──
    Tabs {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(22)
        visible: page.sides.length > 1
        width: Theme.px(128) * page.sides.length
        height: Theme.px(44)
        model: page.sides.map(side => ({ label: side.title, icon: side.icon }))
        current: page.sides.indexOf(page.side)
        accentColor: page.side.hue
        onSelected: index => page.pick(page.sides[index].key)
    }

    PowerButton {
        visible: page.sides.length > 0
        on: page.side.powered
        hue: page.side.hue
        offTitle: page.side.offTitle
        offHint: page.side.offHint
        restCenter: Qt.point(radar.center.x, radar.center.y - Theme.px(24))
        dockCenter: Qt.point(page.width - Theme.px(46), page.height - Theme.px(44))
        onToggled: page.side.setPowered(!page.side.powered)
    }
}
