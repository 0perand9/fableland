import QtQuick
import qs.core
import qs.widgets

// The catalogue as lists: the Movies / Series switch, the search field, the
// order chips and one grid that shows either what is trending (below the recent
// searches and titles) or the results of a search.
//
// Keys: typing searches; Down steps into the grid, where the arrows move and
// Enter opens a title; Tab switches between movies and series.
FocusScope {
    id: view

    property color hue: Theme.accent

    readonly property bool series: Catalog.type === "series"
    readonly property bool searching: Catalog.query !== ""
    readonly property var shelf: searching ? Catalog.found : Catalog.trending
    readonly property var orders: [
        { by: "", label: searching ? "Best match" : "Popular", reversed: "" },
        { by: "year", label: "Newest", reversed: "Oldest" },
        { by: "title", label: "A–Z", reversed: "Z–A" },
        { by: "rating", label: "Top rated", reversed: "Lowest rated" }
    ]

    function searchNow() {
        pause.stop();
        Catalog.search(field.text);
        Catalog.rememberSearch();
    }

    function switchType() {
        Catalog.browse(series ? "movie" : "series");
    }

    // Leaves the grid for the search field.
    function toField() {
        grid.currentIndex = -1;
        field.forceActiveFocus();
    }

    Component.onCompleted: field.text = Catalog.query
    Keys.onTabPressed: switchType()
    Keys.onBacktabPressed: switchType()
    // The grid lets Up through when its cursor is already in the first row.
    Keys.onUpPressed: toField()

    // Searches once typing pauses.
    Timer {
        id: pause

        interval: 400
        onTriggered: {
            if (field.text.trim() !== Catalog.query)
                Catalog.search(field.text);
        }
    }

    Tabs {
        id: types

        x: Theme.px(24)
        y: Theme.px(20)
        width: Theme.px(230)
        height: field.height
        model: [{ label: "Movies", icon: Icons.movie }, { label: "Series", icon: Icons.tv }]
        current: view.series ? 1 : 0
        accentColor: view.hue
        onSelected: index => Catalog.browse(index === 1 ? "series" : "movie")
    }

    Field {
        id: field

        anchors.left: types.right
        anchors.right: orderChips.left
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(14)
        y: types.y
        focus: true
        icon: Icons.search
        placeholder: view.series ? "Search series" : "Search movies"
        accentColor: view.hue
        onTextChanged: {
            // An emptied field goes back to trending at once; anything else waits for a pause.
            if (text.trim() === "")
                searchNow();
            else if (text.trim().length > 1)
                pause.restart();
        }
        onAccepted: searchNow()
        Keys.onDownPressed: {
            if (grid.count === 0)
                return;
            grid.currentIndex = Math.max(0, grid.currentIndex);
            grid.forceActiveFocus();
        }
    }

    Row {
        id: orderChips

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(24)
        anchors.verticalCenter: field.verticalCenter
        spacing: Theme.px(6)

        Repeater {
            model: view.orders

            Chip {
                required property var modelData

                active: Catalog.sortBy === modelData.by
                text: active && Catalog.sortReversed ? modelData.reversed : modelData.label
                hue: view.hue
                onClicked: Catalog.sort(modelData.by)
            }
        }
    }

    GridView {
        id: grid

        readonly property int columns: 8
        // Whether the view rests at its very top, where a growing header must stay in sight.
        property bool atTop: true

        anchors.top: field.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(10)
        // The cells bring their own inset of 8.
        x: Theme.px(16)
        width: parent.width - 2 * x
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.round(cellWidth * 1.5) + Theme.px(48)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // One row beyond the visible ones is kept ready.
        cacheBuffer: cellHeight
        currentIndex: -1
        model: Catalog.titles
        onModelChanged: currentIndex = -1
        onContentYChanged: atTop = atYBeginning
        // The header grows when the history arrives; a view at the top follows it up.
        onOriginYChanged: {
            if (atTop)
                positionViewAtBeginning();
        }
        Keys.onReturnPressed: {
            if (currentIndex >= 0)
                Catalog.show(Catalog.titles[currentIndex]);
        }
        // Typing while in the grid continues the search.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace)
                field.text = field.text.slice(0, -1);
            else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                field.text += event.text;
            else
                return;
            view.toField();
            event.accepted = true;
        }

        header: Column {
            width: grid.width
            leftPadding: Theme.px(8)
            topPadding: Theme.px(10)
            bottomPadding: Theme.px(6)
            spacing: Theme.px(20)

            Dashboard {
                visible: !view.searching
                width: parent.width - 2 * parent.leftPadding
                hue: view.hue
                onSearchPicked: query => {
                    field.text = query;
                    view.searchNow();
                }
            }

            Heading {
                text: view.searching ? "Results for “" + Catalog.query + "”" : view.series ? "Trending series" : "Trending movies"
            }
        }

        delegate: TitleCell {
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight
            title: modelData
            current: GridView.isCurrentItem && grid.activeFocus
            hue: view.hue
            onPicked: Catalog.show(modelData)
        }

        // Shown in place of the titles while there are none.
        footer: Item {
            width: grid.width
            height: visible ? Theme.px(300) : 0
            visible: Catalog.titles.length === 0

            Notice {
                anchors.centerIn: parent
                busy: view.shelf.loading
                hue: view.hue
                icon: view.shelf.error !== "" ? Icons.error : view.searching ? Icons.search : Icons.movie
                text: view.shelf.loading ? (view.searching ? "Searching the catalogue…" : "Looking up what is trending…")
                    : view.shelf.error !== "" ? "The catalogue did not answer: " + view.shelf.error
                    : view.searching ? "Nothing found for “" + Catalog.query + "”" : "Nothing is trending right now"
                action: view.shelf.error !== "" ? "Try again" : ""
                onTriggered: view.searching ? Catalog.search(Catalog.query) : Catalog.loadTrending()
            }
        }
    }

    Scroller {
        target: grid
    }
}
