import QtQuick
import qs.core
import qs.widgets
import qs.popups.clipboard

// The clipboard history: a grid of what was copied, newest first, searched by
// the daemon and loaded a page at a time as the grid scrolls. Enter or a click
// copies an entry again; Tab or a right click shows it in full.
PopupPage {
    id: page

    readonly property int columns: 3
    readonly property int visibleRows: 4
    // The gap between two cards.
    readonly property int gap: Theme.px(10)

    // Showing the selected entry in full, over the cards.
    property bool previewing: false
    // The selected entry's cell (see the grid's delegate), or null.
    readonly property Item cell: cards.currentItem
    readonly property string selectedKey: cell ? cell.key : ""
    // The entry whose full text is wanted, "" for none.
    readonly property string previewKey: previewing && cell && cell.kind === "text" ? cell.key : ""
    // The full text of that entry, once the daemon has sent it — or why it did not.
    property string fullText: ""
    property string fullTextError: ""

    function copy(key) {
        if (key === "")
            return;
        Daemon.send("clipboard.copy", { id: key });
        close();
    }

    function select(index) {
        if (cards.count > 0)
            cards.currentIndex = Math.max(0, Math.min(cards.count - 1, index));
    }

    // Up or down by whole rows: past the top it stops in the first row, past the bottom on the last card.
    function selectRows(rows) {
        const target = cards.currentIndex + rows * columns;
        select(target < 0 ? cards.currentIndex % columns : target);
    }

    function navigate(where) {
        if (where === "next" || where === "previous") {
            previewing = !previewing && selectedKey !== "";
            return;
        }
        // In the preview Left and Right still step through the entries; the rest scrolls it.
        const browsing = !previewing || where === "left" || where === "right";
        switch (where) {
        case "left": select(cards.currentIndex - 1); break;
        case "right": select(cards.currentIndex + 1); break;
        case "up": browsing ? selectRows(-1) : preview.scrollBy(-Theme.px(80)); break;
        case "down": browsing ? selectRows(1) : preview.scrollBy(Theme.px(80)); break;
        case "pageUp": browsing ? selectRows(-visibleRows) : preview.scrollBy(-0.85 * preview.height); break;
        case "pageDown": browsing ? selectRows(visibleRows) : preview.scrollBy(0.85 * preview.height); break;
        case "first": browsing ? select(0) : preview.scrollBy(-Infinity); break;
        case "last": browsing ? select(cards.count - 1) : preview.scrollBy(Infinity); break;
        }
    }

    implicitWidth: Theme.px(800)
    implicitHeight: Theme.px(700)
    closeOnEscape: !previewing

    // Escape leaves the preview first. Otherwise it is left to the host, which closes the popup.
    Keys.onEscapePressed: event => {
        event.accepted = previewing;
        previewing = false;
    }

    onSelectedKeyChanged: {
        if (selectedKey === "")
            previewing = false;
    }
    onPreviewKeyChanged: {
        const key = previewKey;
        fullText = "";
        fullTextError = "";
        preview.rewind();
        if (key !== "")
            Daemon.call("clipboard.text", { id: key }, (text, error) => {
                if (key !== page.previewKey)
                    return;
                page.fullText = text ?? "";
                page.fullTextError = error ?? "";
            });
    }

    History {
        id: history

        query: search.text.trim()
        onReplaced: {
            glide.stop();
            cards.currentIndex = entries.count > 0 ? 0 : -1;
            cards.positionViewAtBeginning();
        }
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue]
    }

    SearchBar {
        id: search

        width: parent.width
        focus: true
        grid: true
        placeholder: "Search the clipboard"
        icon: page.previewing ? Icons.eye : Icons.clipboard
        onTextChanged: page.previewing = false
        onAccepted: page.copy(page.selectedKey)
        onNavigate: where => page.navigate(where)
        onKeyPressed: event => {
            if (event.key !== Qt.Key_Delete || page.selectedKey === "")
                return;
            history.remove(page.selectedKey);
            event.accepted = true;
        }

        HoldBtn {
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.px(34)
            visible: history.total > 0
            text: "Wipe all"
            icon: Icons.trash
            size: 12
            onTriggered: history.wipe()
        }
    }

    Rectangle {
        id: divider

        anchors.top: search.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    Spinner {
        anchors.centerIn: cards
        visible: history.loading && cards.count === 0
    }

    Txt {
        anchors.centerIn: cards
        width: cards.width - Theme.px(80)
        visible: !history.loading && cards.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: history.error !== "" ? "The clipboard history is not available:\n" + history.error
            : history.query !== "" ? "Nothing in the clipboard history matches “" + history.query + "”"
            : "Nothing has been copied yet"
        color: Theme.dim
    }

    GridView {
        id: cards

        // Where in the grid's content the cell of `index` is.
        function cellX(index) {
            return (index % page.columns) * cellWidth;
        }

        function cellY(index) {
            return originY + Math.floor(index / page.columns) * cellHeight;
        }

        // Scroll just far enough to show the row of `index`.
        function reveal(index) {
            const top = cellY(index);
            const target = Math.max(top + cellHeight - height, Math.min(top, contentY));
            if (target === contentY)
                return;
            glide.to = target;
            glide.restart();
        }

        anchors.top: divider.bottom
        anchors.bottom: footer.top
        anchors.topMargin: page.gap / 2
        anchors.bottomMargin: page.gap / 2
        x: page.gap / 2
        width: parent.width - 2 * x
        cellWidth: Math.floor(width / page.columns)
        cellHeight: Math.floor(height / page.visibleRows)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Text cards are cheap, thumbnails are not: keep a screenful ready either side.
        cacheBuffer: Math.max(0, height)
        model: history.entries
        // Off while the preview covers the cards.
        interactive: !page.previewing
        onCurrentIndexChanged: {
            if (currentIndex < 0)
                return;
            reveal(currentIndex);
            if (currentIndex >= count - 2 * page.columns)
                history.loadMore();
        }
        onContentYChanged: {
            if (contentY + height > originY + contentHeight - 2 * cellHeight)
                history.loadMore();
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: entry

            required property int index
            required property string key
            required property string kind
            required property string text
            required property string image

            width: cards.cellWidth
            height: cards.cellHeight

            ClipCard {
                anchors.fill: parent
                anchors.margins: page.gap / 2
                number: entry.index + 1
                kind: entry.kind
                text: entry.text
                image: entry.image
                selected: entry.GridView.isCurrentItem
                onClicked: mouse => {
                    cards.currentIndex = entry.index;
                    if (mouse.button === Qt.RightButton)
                        page.previewing = true;
                    else
                        page.copy(entry.key);
                }
                onRemoveRequested: history.remove(entry.key)
            }
        }

        NumberAnimation {
            id: glide

            target: cards
            property: "contentY"
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }

        // The selection, under the cards and scrolling with them: it stretches
        // along a row and slides between rows.
        Stretch {
            // While the list is being replaced nothing is selected; stay put instead of leaving and returning.
            readonly property int index: Math.max(0, cards.currentIndex)

            parent: cards.contentItem
            visible: cards.currentIndex >= 0
            radius: Theme.radius
            color: Theme.alpha(Theme.accent, 0.2)
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.75)
            y: cards.cellY(index) + page.gap / 2
            height: cards.cellHeight - page.gap
            targetStart: cards.cellX(index) + page.gap / 2
            targetEnd: targetStart + cards.cellWidth - page.gap

            Behavior on y {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }
        }
    }

    Scroller {
        target: cards
    }

    Preview {
        id: preview

        anchors.fill: cards
        anchors.margins: page.gap / 2
        shown: page.previewing
        origin: page.cell ? Qt.rect(page.cell.x, page.cell.y - cards.contentY, page.cell.width - page.gap, page.cell.height - page.gap) : Qt.rect(0, 0, 0, 0)
        kind: page.cell ? page.cell.kind : "text"
        text: page.fullText !== "" ? page.fullText : page.cell ? page.cell.text : ""
        image: page.cell ? page.cell.image : ""
        caption: {
            if (kind === "image")
                return text;
            if (page.fullText === "")
                return page.fullTextError !== "" ? page.fullTextError : "Loading…";
            const lines = page.fullText.split("\n").length;
            const cut = page.fullText.length > textLimit ? " · the first " + textLimit + " shown" : "";
            return page.fullText.length + " characters · " + lines + (lines === 1 ? " line" : " lines") + cut;
        }
        onCopyRequested: page.copy(page.selectedKey)
        onDismissed: page.previewing = false
    }

    Item {
        id: footer

        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(40)

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Txt {
            x: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            visible: cards.count > 0
            text: (cards.currentIndex + 1) + " of " + history.total + (history.query !== "" ? " matches" : "")
            size: 11
            color: Theme.dim
        }

        KeyHints {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            model: {
                const acting = [{ key: "Enter", label: "Copy" }, { key: "Del", label: "Delete" }];
                if (!page.previewing)
                    return acting.concat({ key: "Tab", label: "Preview" });
                const scrolling = preview.kind === "text" ? [{ key: "↑↓", label: "Scroll" }] : [];
                return [{ key: "←→", label: "Browse" }].concat(scrolling, acting, { key: "Tab", label: "Back" });
            }
        }
    }
}
