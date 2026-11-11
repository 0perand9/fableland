import QtQuick
import qs.core
import qs.widgets

// What each part of the shell does, with a button to try it. Arrow keys move a
// cursor over the cards and Enter tries the one under it. A part that is a
// feature (Daemon.has) names it as `feature`, and is left out while that is off.
FocusScope {
    id: view

    // Asks the guide to show another section.
    signal navigate(string section)

    readonly property int columns: 3
    readonly property int gutter: Theme.px(12)
    readonly property var sections: everything.map(section => ({ title: section.title, items: section.items.filter(item => Daemon.has(item.feature ?? "")) }))
    readonly property var everything: [
        {
            title: "Pop-ups",
            items: [
                popup("launcher", Icons.rocket, "Launcher", "Start an application by typing its name — the ones you use most come first — or run a command."),
                popup("clipboard", Icons.clipboard, "Clipboard", "Everything you copied, text and images alike. Search it and pick an entry to copy it again."),
                popup("wallpaper", Icons.wallpaper, "Wallpapers", "Browse your wallpaper folder by colour or search for new ones." + (Daemon.has("palette") ? " The palette follows your pick." : "")),
                popup("calendar", Icons.calendar, "Calendar", "The month, " + (Daemon.has("weather") ? "the weather hour by hour, " : "") + "today's schedule and a diary note for any day."),
                popup("music", Icons.music, "Music", "What is playing, with seeking and a choice of players, and a ten-band equalizer."),
                popup("network", Icons.wifi, "Network", "Wi-Fi and Bluetooth in one place: scan, connect, pair and forget."),
                popup("volume", Icons.volumeHigh, "Volume", "Output and input devices, and a volume slider for every application making sound."),
                popup("control", Icons.tune, "Control center", (Daemon.has("notifications") ? "Notifications you missed, do not disturb, brightness" : "Brightness") + ", power profiles and the session buttons."),
                popup("focus", Icons.target, "Focus", "Where your screen time goes: per application, per day and week, with a heat map of your hours."),
                popup("monitors", Icons.monitors, "Monitors", "Arrange your displays and set resolution, refresh rate, scale and rotation."),
                popup("settings", Icons.settings, "Settings", "Everything that can be changed: keybinds, keyboard layouts, start-up programs and more."),
                popup("updates", Icons.update, "Updates", "Which inputs of your system flake are behind, and one button to update them."),
                popup("movies", Icons.movie, "Movies", "Trending films and series, a catalogue search and a link that opens a title where you watch."),
                popup("assistant", Icons.robot, "Assistant", "Ask a question without leaving what you are doing.")
            ]
        },
        {
            title: "Around the desktop",
            items: [
                { icon: Icons.dockTop, title: "The bar", command: "", action: "", text: "Workspaces, the player, the clock, the tray and status pills. Click a pill to open its pop-up." },
                { feature: "notifications", icon: Icons.bell, title: "Notifications", command: "fable dnd", action: "Send one", act: () => Daemon.send("notif.test", { summary: "Hello from the guide", body: "This is what a notification looks like." }),
                  text: "They pop up as they arrive and collect in the control center. Right-click the bell in the bar for do not disturb." },
                { feature: "quick", icon: Icons.draw, title: "Quick panel", command: "fable toggle quick", action: "Try it", act: () => quickPanel(),
                  text: "Rest the pointer on a screen edge for small tools that stay out of the way: drawing on the screen, live system usage, and a timer, stopwatch and pomodoro." },
                { feature: "capture", icon: Icons.screenshot, title: "Screenshots & recording", command: "fable capture region", action: "Take one", act: () => capture(),
                  text: "Select a region to copy, annotate, read as text or scan for a QR code — or record it, with or without sound." },
                { feature: "lock", icon: Icons.lock, title: "Lock screen", command: "fable lock", action: "Lock now", act: () => Daemon.send("session.lock"), text: "Locks the session until you type your password. It can lock by itself after some idle minutes." },
                { feature: "palette", icon: Icons.palette, title: "Colours", command: "", action: "See how", act: () => view.navigate("theme"), text: "The whole palette is generated from your wallpaper and fades over when it changes." }
            ]
        }
    ]
    // Rows of card numbers as they are laid out, section after section, for moving the cursor.
    readonly property var layout: {
        const rows = [];
        let first = 0;
        for (const section of sections) {
            for (let i = 0; i < section.items.length; i += columns)
                rows.push(Array.from({ length: Math.min(columns, section.items.length - i) }, (_, n) => first + i + n));
            first += section.items.length;
        }
        return rows;
    }
    readonly property var features: sections.reduce((all, section) => all.concat(section.items), [])
    // The card under the keyboard cursor, -1 before any arrow key.
    property int cursor: -1

    // A popup that is a feature carries the feature's name (see Ui.popups); for the others `feature` names nothing.
    function popup(name, icon, title, text) {
        return { feature: name, icon: icon, title: title, text: text, command: "fable toggle " + name, action: "Try it", act: () => Ui.open(name) };
    }

    // The panel comes out at the screen's edge; the guide steps aside to show it.
    function quickPanel() {
        Ui.close();
        Ui.open("quick");
    }

    // The guide steps aside first, so that it is not what gets captured.
    function capture() {
        Ui.close();
        Daemon.send("capture.start", { mode: "region" });
    }

    // The features are looked up here rather than taken from a card's model data,
    // which does not carry their functions.
    function tryFeature(number) {
        const feature = features[number];
        if (feature && feature.act)
            feature.act();
    }

    function move(columnsBy, rowsBy) {
        if (cursor < 0) {
            cursor = 0;
            return;
        }
        if (columnsBy !== 0) {
            cursor = Math.max(0, Math.min(features.length - 1, cursor + columnsBy));
            return;
        }
        const row = layout.findIndex(cards => cards.indexOf(cursor) >= 0);
        const target = layout[Math.max(0, Math.min(layout.length - 1, row + rowsBy))];
        cursor = target[Math.min(layout[row].indexOf(cursor), target.length - 1)];
    }

    // Scrolls just enough to bring a card into view.
    function reveal(card) {
        const top = card.mapToItem(scroll.contentItem, 0, 0).y, margin = Theme.px(12);
        if (top - margin < scroll.contentY)
            glide.to = Math.max(0, top - margin);
        else if (top + card.height + margin > scroll.contentY + scroll.height)
            glide.to = top + card.height + margin - scroll.height;
        else
            return;
        glide.restart();
    }

    focus: true
    Keys.onLeftPressed: move(-1, 0)
    Keys.onRightPressed: move(1, 0)
    Keys.onUpPressed: move(0, -1)
    Keys.onDownPressed: move(0, 1)
    Keys.onReturnPressed: tryFeature(cursor)

    NumberAnimation {
        id: glide

        target: scroll
        property: "contentY"
        duration: Theme.normal
        easing.type: Easing.OutCubic
    }

    PageTitle {
        id: title

        width: parent.width
        title: "Take the tour"
        subtitle: "Everything the shell is made of. Arrow keys move, Enter tries."
    }

    Scroll {
        id: scroll

        anchors.top: title.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(14)
        // Wider than the cards, so that the scroll indicator runs beside them.
        width: parent.width + view.gutter

        Column {
            width: parent.width - view.gutter
            spacing: Theme.px(10)

            Repeater {
                model: view.sections

                Column {
                    id: section

                    required property var modelData
                    required property int index
                    // The number of this section's first card among all cards.
                    readonly property int first: view.sections.slice(0, index).reduce((n, s) => n + s.items.length, 0)

                    width: parent.width
                    spacing: Theme.px(10)

                    Heading {
                        topPadding: Theme.px(6)
                        text: section.modelData.title
                    }

                    Grid {
                        id: cards

                        width: parent.width
                        columns: view.columns
                        spacing: Theme.px(12)

                        Repeater {
                            model: section.modelData.items

                            FeatureCard {
                                required property var modelData
                                required property int index

                                width: (cards.width - (view.columns - 1) * cards.spacing) / view.columns
                                icon: modelData.icon
                                title: modelData.title
                                text: modelData.text
                                command: modelData.command
                                action: modelData.action
                                selected: view.cursor === section.first + index
                                onSelectedChanged: {
                                    if (selected)
                                        view.reveal(this);
                                }
                                onTried: view.tryFeature(section.first + index)
                            }
                        }
                    }
                }
            }

            // Room below the last row, so its cards do not sit on the popup's edge.
            Item {
                width: 1
                height: Theme.px(4)
            }
        }
    }
}
