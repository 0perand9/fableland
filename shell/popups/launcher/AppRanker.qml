import QtQuick

// Ranks applications against a query. Where a word of the query is found
// decides: the start of the name beats the start of a word, which beats
// anywhere inside; the name beats the generic name and keywords, which beat
// the comment. Equal matches go to the application used most.
QtObject {
    id: root

    // The `apps` topic.
    property var apps: []

    // Lower-cased copies of what is searched, made once per application list
    // instead of on every keystroke.
    readonly property var index: apps.map(app => {
        const name = (app.name ?? "").toLowerCase();
        return {
            app: app,
            name: name,
            // "visual studio code" → "vsc"
            initials: name.split(/[^a-z0-9]+/).map(word => word.charAt(0)).join(""),
            // Keywords follow a space, so they can only ever match as words.
            generic: ((app.generic ?? "") + " " + (app.keywords ?? "")).toLowerCase(),
            comment: (app.comment ?? "").toLowerCase()
        };
    })

    function isWordCharacter(c) {
        return (c >= "a" && c <= "z") || (c >= "0" && c <= "9");
    }

    // How `word` sits in `text`: 3 at its very start, 2 at the start of a word, 1 inside one, 0 not at all.
    function placement(text, word) {
        let at = text.indexOf(word);
        if (at <= 0)
            return at === 0 ? 3 : 0;
        for (; at >= 0; at = text.indexOf(word, at + 1))
            if (!isWordCharacter(text.charAt(at - 1)))
                return 2;
        return 1;
    }

    // 9 name start · 8 name word · 7 generic start · 6 inside the name, or its initials
    // 5 generic/keyword word · 4 inside those · 3–1 the comment · 0 no match
    function score(entry, word) {
        const name = placement(entry.name, word);
        if (name >= 2)
            return name + 6;
        const generic = placement(entry.generic, word);
        if (generic === 3)
            return 7;
        if (name === 1 || (word.length > 1 && entry.initials.startsWith(word)))
            return 6;
        return generic > 0 ? generic + 3 : placement(entry.comment, word);
    }

    // The applications matching every word of `query`, best first. An empty
    // query matches everything: most used first, then alphabetically.
    function rank(query) {
        const words = query.toLowerCase().split(/\s+/).filter(word => word !== "");
        const hits = [];
        for (let i = 0; i < index.length; i++) {
            // An application is as good as its weakest word.
            let weakest = 9;
            for (let w = 0; w < words.length && weakest > 0; w++)
                weakest = Math.min(weakest, score(index[i], words[w]));
            if (weakest > 0)
                hits.push({ app: index[i].app, score: weakest, order: i });
        }
        // `apps` arrives sorted by name, so its order settles what is left.
        hits.sort((a, b) => b.score - a.score || b.app.uses - a.app.uses || b.app.lastUsed - a.app.lastUsed || a.order - b.order);
        return hits.map(hit => hit.app);
    }
}
