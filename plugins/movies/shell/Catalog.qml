pragma Singleton
import QtQuick
import Quickshell
import qs.core

// What the movies popup shows: the film and series catalogue as the daemon
// serves it (`movies.*`). It lives outside the popup so that reopening it
// brings back the same list, search and title at once — and so that a reply
// arriving after the popup has closed still has somewhere to land.
Singleton {
    id: root

    // A list fetched from the daemon, with the state of its request.
    component Shelf: QtObject {
        property var items: []
        property bool loaded: false
        property bool loading: false
        property string error: ""
    }

    // "movie" or "series": what the lists and the search are about.
    property string type: "movie"
    // The search on show; "" shows what is trending.
    property string query: ""
    // "" keeps the order the catalogue gave; "year", "title" and "rating" sort by that.
    property string sortBy: ""
    // Oldest, Z–A or lowest-rated first instead of the usual direction.
    property bool sortReversed: false

    readonly property Shelf movies: Shelf {}
    readonly property Shelf series: Shelf {}
    readonly property Shelf trending: type === "series" ? series : movies
    readonly property Shelf found: Shelf {}
    // The list to show, in the chosen order.
    readonly property var titles: sorted(query !== "" ? found.items : trending.items)

    // What the daemon remembers: past searches and the titles opened last.
    property var searches: []
    property var watched: []

    // The title whose details are on show (an entry of a list), or null while browsing.
    property var selected: null
    // Its full description, once `movies.details` has answered.
    property var details: null
    property bool detailsLoading: false
    property string detailsError: ""
    // The episode the Open button is about (series only).
    property int season: 0
    property int episode: 0
    readonly property var episodes: details?.episodes ?? []
    readonly property var seasons: episodes.reduce((all, e) => all.indexOf(e.season) < 0 ? all.concat([e.season]) : all, [])
    readonly property var seasonEpisodes: episodes.filter(e => e.season === season)

    // Why the last action (opening a title, forgetting a search) failed, for the popup to show.
    property string problem: ""

    // The link was handed to the browser; the popup has done its job.
    signal opened

    // The popup has opened: bring everything up to date.
    function enter() {
        problem = "";
        refreshHistory();
        loadTrending();
        if (selected && !details && !detailsLoading)
            loadDetails();
    }

    function browse(type) {
        root.type = type;
        if (query !== "")
            search(query);
        else if (!trending.loaded)
            loadTrending();
    }

    function loadTrending() {
        const shelf = trending;
        if (shelf.loading)
            return;
        shelf.loading = true;
        Daemon.call("movies.trending", { type: root.type }, (items, error) => {
            shelf.loading = false;
            shelf.error = error ?? "";
            if (error)
                return;
            shelf.items = items;
            shelf.loaded = true;
        });
    }

    function search(text) {
        const query = text.trim(), type = root.type;
        root.query = query;
        // Nothing is known about this search yet; the last one's results would be a lie.
        found.items = [];
        found.error = "";
        found.loading = query !== "";
        if (query === "")
            return;
        Daemon.call("movies.search", { query: query, type: type }, (items, error) => {
            // An answer to a search the user has moved on from is dropped.
            if (root.query !== query || root.type !== type)
                return;
            found.loading = false;
            found.error = error ?? "";
            found.items = error ? [] : items;
        });
    }

    // Clicking the current order again turns it around.
    function sort(by) {
        sortReversed = by !== "" && by === sortBy && !sortReversed;
        sortBy = by;
    }

    function sorted(items) {
        if (sortBy === "")
            return items;
        const way = sortReversed ? -1 : 1;
        if (sortBy === "title")
            return items.slice().sort((a, b) => way * String(a.title).localeCompare(String(b.title)));
        // "2008–2013" counts as 2008. Titles without the value go last, whichever way round.
        const number = title => parseFloat(title[sortBy]);
        return items.slice().sort((a, b) => {
            const x = number(a), y = number(b);
            return isNaN(x) || isNaN(y) ? isNaN(x) - isNaN(y) : way * (y - x);
        });
    }

    function refreshHistory() {
        Daemon.call("movies.history", {}, (history, error) => {
            if (!error)
                adopt(history);
        });
    }

    function adopt(history) {
        searches = history.searches ?? [];
        watched = history.watched ?? [];
    }

    function forget(query) {
        Daemon.call("movies.forgetSearch", { query: query }, (history, error) => {
            if (error)
                problem = error;
            else
                adopt(history);
        });
    }

    // Keeps the current search among the recent ones. Called when the user
    // commits to it (Enter, or opening one of its results), not while typing.
    function rememberSearch() {
        if (query === "")
            return;
        Daemon.call("movies.rememberSearch", { query: query }, (history, error) => {
            if (!error)
                adopt(history);
        });
    }

    function show(title) {
        rememberSearch();
        selected = title;
        details = null;
        season = 0;
        episode = 0;
        loadDetails();
    }

    function loadDetails() {
        const id = selected.id;
        detailsLoading = true;
        detailsError = "";
        Daemon.call("movies.details", { id: id, type: selected.type }, (details, error) => {
            // The user may have gone back, or on to another title, meanwhile.
            if (root.selected?.id !== id)
                return;
            detailsLoading = false;
            detailsError = error ?? "";
            if (error)
                return;
            root.details = details;
            pickSeason(details.episodes.length > 0 ? details.episodes[0].season : 0);
        });
    }

    function back() {
        selected = null;
        details = null;
        detailsLoading = false;
    }

    // Selects a season and its first episode.
    function pickSeason(season) {
        root.season = season;
        root.episode = seasonEpisodes.length > 0 ? seasonEpisodes[0].episode : 0;
    }

    // Opens the selected title (for a series: the selected episode) with the `movies.openWith` link.
    function open() {
        const params = { id: selected.id, title: details?.title ?? selected.title, poster: selected.poster ?? "", type: selected.type };
        if (episodes.length > 0) {
            params.season = season;
            params.episode = episode;
        }
        Daemon.call("movies.open", params, (history, error) => {
            if (error) {
                problem = error;
                return;
            }
            adopt(history);
            opened();
        });
    }
}
