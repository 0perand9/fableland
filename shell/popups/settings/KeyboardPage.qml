import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    id: page

    // Every layout xkb knows, fetched once: [{ id, name }].
    property var catalog: []
    readonly property var names: {
        const map = {};
        for (const layout of catalog)
            map[layout.id] = layout.name;
        return map;
    }

    // keyboard.options is a comma-separated list of xkb options; the one that
    // switches between layouts gets a control of its own.
    readonly property var options: Daemon.setting("keyboard.options", "").split(",").map(option => option.trim()).filter(option => option !== "")
    readonly property var switches: [
        { option: "", label: "Nothing" },
        { option: "grp:alt_shift_toggle", label: "Alt + Shift" },
        { option: "grp:win_space_toggle", label: "Super + Space" },
        { option: "grp:ctrl_shift_toggle", label: "Ctrl + Shift" },
        { option: "grp:ctrl_alt_toggle", label: "Ctrl + Alt" },
        { option: "grp:caps_toggle", label: "Caps Lock" },
        { option: "grp:toggle", label: "Right Alt" }
    ]
    readonly property int currentSwitch: {
        const known = switches.findIndex(entry => entry.option !== "" && options.indexOf(entry.option) >= 0);
        if (known >= 0)
            return known;
        // A switch this page has no chip for: none of them is the truth, not even "Nothing".
        return options.some(option => option.startsWith("grp:")) ? -1 : 0;
    }

    function setSwitch(index) {
        const others = options.filter(option => !switches.some(entry => entry.option === option));
        const option = switches[index].option;
        Daemon.setSetting("keyboard.options", (option === "" ? others : others.concat([option])).join(","));
    }

    Component.onCompleted: Daemon.call("misc.xkbLayouts", {}, found => {
        if (page)
            catalog = found ?? [];
    })

    ListEditor {
        id: layouts

        title: "Layouts"
        path: "keyboard.layouts"
        emptyText: "None chosen, so the layouts of your Hyprland configuration apply. Add some below; the first one is the default."
        matches: layout => Search.matches("keyboard.layouts language", layout, page.names[layout] ?? "")
        delegate: LayoutRow {
            editor: layouts
            names: page.names
        }
    }

    Section {
        title: "Add a layout"

        SettingRow {
            keywords: "keyboard.layouts language add xkb"
            stacked: true
            // Nothing can be added to a list the system configuration fixes.
            available: !layouts.fixed
            onActivated: picker.focusField()

            LayoutPicker {
                id: picker

                catalog: page.catalog
                chosen: layouts.entries
                onPicked: id => layouts.append(id)
            }
        }
    }

    Section {
        title: "Options"

        SettingRow {
            path: "keyboard.options"
            label: "Switch layouts with"
            keywords: "shortcut toggle grp"
            stacked: true
            onNudged: by => page.setSwitch(Math.max(0, Math.min(page.switches.length - 1, page.currentSwitch + by)))

            Chips {
                labels: page.switches.map(entry => entry.label)
                current: page.currentSwitch
                onPicked: index => page.setSwitch(index)
            }
        }

        TextRow {
            path: "keyboard.options"
            label: "XKB options"
            hint: "Comma-separated, like caps:escape. They are applied together with the layouts, so they need at least one layout above."
            keywords: "xkb"
            placeholder: "None"
        }
    }
}
