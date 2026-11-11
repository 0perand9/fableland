.pragma library

// Turns Hyprland's bind list (the daemon's `hypr.binds`) into what the keybind
// cheat-sheet shows: key-cap labels, a readable action and a group. Pure
// functions only, so the view stays declarative.

const MODIFIERS = { SUPER: "Super", CTRL: "Ctrl", CONTROL: "Ctrl", ALT: "Alt", SHIFT: "Shift" };
const NAMED_KEYS = { return: "Enter", escape: "Esc", space: "Space", left: "←", right: "→", up: "↑", down: "↓", mouse_up: "Wheel up", mouse_down: "Wheel down" };
// Linux button codes, as in `mouse:272`.
const MOUSE_BUTTONS = { 272: "Left click", 273: "Right click", 274: "Middle click", 275: "Side button", 276: "Extra button" };
// `code:44` names a physical key; label it with what a US keyboard prints there.
const KEYCODE_ROWS = [[10, "1234567890"], [24, "QWERTYUIOP"], [38, "ASDFGHJKL"], [52, "ZXCVBNM"]];

const DISPATCHERS = { exec_cmd: "Run a command", close: "Close window", exit: "Exit Hyprland", pseudo: "Pseudo-tile", toggle_special: "Toggle special workspace" };
const DIRECTIONS = { left: "left", right: "right", up: "up", down: "down", h: "left", j: "down", k: "up", l: "right" };

// Sections of the cheat-sheet, in display order. Submaps are appended as they are found.
const GROUPS = [
    { id: "shell", title: "Fableland" },
    { id: "launch", title: "Launch & run" },
    { id: "windows", title: "Windows & session" },
    { id: "workspaces", title: "Workspaces" },
    { id: "media", title: "Media & hardware keys" }
];

// The key a bind names, by the letter or digit printed on it ("code:44" → "J"); "" for anything else.
function printedKey(key) {
    const code = /^code:(\d+)$/.exec(key);
    if (!code)
        return key.length === 1 ? key.toUpperCase() : "";
    const n = Number(code[1]);
    for (const [first, keys] of KEYCODE_ROWS)
        if (n >= first && n < first + keys.length)
            return keys[n - first];
    return "";
}

// What to print on the key cap.
function keyLabel(key) {
    const printed = printedKey(key);
    if (printed)
        return printed;
    const lower = key.toLowerCase();
    if (lower in NAMED_KEYS)
        return NAMED_KEYS[lower];
    const button = /^mouse:(\d+)$/.exec(lower);
    if (button)
        return MOUSE_BUTTONS[button[1]] ?? "Mouse " + button[1];
    if (lower.startsWith("code:"))
        return "Key " + key.slice(5);
    if (key.startsWith("XF86"))
        return key.slice(4).replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    return key.charAt(0).toUpperCase() + key.slice(1);
}

function words(dispatcher) {
    const text = dispatcher.replace(/[_.]+/g, " ").trim();
    return text.charAt(0).toUpperCase() + text.slice(1);
}

// A dispatcher name a person can read: "toggle_special" → "Toggle special workspace".
function readable(dispatcher) {
    // Hyprland reports a Lua closure as "function: 0x55…".
    if (dispatcher.startsWith("function"))
        return "Lua function";
    return DISPATCHERS[dispatcher] ?? words(dispatcher || "unknown");
}

// Binds made in a loop reach the daemon without a description. Their keys still
// say what they aim at: a digit is a workspace, an arrow or h/j/k/l a direction.
function aim(key) {
    const printed = printedKey(key);
    if (/^[0-9]$/.test(printed))
        return "workspace " + (printed === "0" ? "10" : printed);
    return DIRECTIONS[(printed || key).toLowerCase()] ?? "";
}

// "SUPER + SHIFT + s" and { mods: ["SUPER", "SHIFT"], key: "S" } give the same id.
function comboId(mods, key) {
    return mods.map(m => MODIFIERS[m.toUpperCase()] ?? m).sort().join("+") + "+" + key.toLowerCase();
}

// The binds from the `keybinds` setting by combo: Hyprland cannot say what those
// do, but the setting can.
function userBinds(setting) {
    const known = {};
    for (const bind of setting ?? []) {
        const parts = String(bind.keys ?? "").split("+").map(p => p.trim()).filter(p => p !== "");
        const command = String(bind.command ?? "").trim();
        if (parts.length === 0 || command === "")
            continue;
        const key = parts.pop();
        known[comboId(parts, key)] = { command: bind.action === "fable" ? "fable " + command : command, description: bind.description ?? "" };
    }
    return known;
}

// One bind as the cheat-sheet shows it.
function describe(bind, known) {
    const user = known[comboId(bind.mods, bind.key)];
    // `event("fable toggle launcher")` is how a bind hands a command to the daemon.
    const event = /^event\(\s*["'](.*)["']\s*\)$/.exec(bind.action);
    const command = user ? user.command : event ? event[1] : bind.action;
    const submap = /^submap\(\s*["'](.*)["']\s*\)$/.exec(bind.action);
    const target = command === "" ? aim(bind.key) : "";
    const isShell = /^fable\b/.test(command);

    let title = command, detail = "";
    if (user && user.description !== "") {
        title = user.description;
        detail = command;
    } else if (submap) {
        title = submap[1] === "reset" ? "Leave the submap" : "Enter submap " + submap[1];
    } else if (command === "" || bind.dispatcher.startsWith("function")) {
        title = readable(bind.dispatcher);
        if (target !== "" && bind.dispatcher !== "exec_cmd")
            title = (bind.dispatcher === "move" && target.startsWith("workspace") ? "Move to " : words(bind.dispatcher) + " ") + target;
    } else if (!isShell && bind.dispatcher !== "exec_cmd") {
        title = readable(bind.dispatcher);
        detail = command;
    }

    let group = "windows";
    if (bind.submap !== "")
        group = "submap:" + bind.submap;
    else if (submap && submap[1] !== "reset")
        group = "submap:" + submap[1];
    else if (bind.key.startsWith("XF86"))
        group = "media";
    else if (isShell)
        group = "shell";
    else if (bind.dispatcher === "exec_cmd")
        group = "launch";
    else if (/workspace|special/.test(command + " " + bind.dispatcher + " " + target))
        group = "workspaces";

    const mods = bind.mods.map(m => MODIFIERS[m] ?? m);
    const key = keyLabel(bind.key);
    return {
        mods: mods, key: key, title: title, detail: detail, group: group,
        repeat: !!bind.repeat, locked: !!bind.locked, mouse: !!bind.mouse,
        haystack: [mods.join(" "), key, bind.key, title, detail].join(" ").toLowerCase()
    };
}

// Every bind described, plus the groups that occur (in display order, with counts).
function sheet(binds, setting) {
    const known = userBinds(setting);
    const entries = (binds ?? []).map(b => describe(b, known));
    const groups = GROUPS.map(g => ({ id: g.id, title: g.title }));
    for (const entry of entries)
        if (!groups.some(g => g.id === entry.group))
            groups.push({ id: entry.group, title: "Submap · " + entry.group.slice(7) });
    return { entries: entries, groups: groups };
}

// The entries matching every word of `query` ("super shift s", "super+s", "volume").
// A single character means that key, not any text containing it.
function matching(entries, query) {
    const wanted = query.toLowerCase().replace(/\+/g, " ").split(/\s+/).filter(w => w !== "");
    const hit = (entry, word) => word.length === 1 ? entry.key.toLowerCase() === word : entry.haystack.indexOf(word) >= 0;
    return entries.filter(e => wanted.every(w => hit(e, w)));
}

// The list the view shows: a header row before the binds of each group.
function rows(entries, groups) {
    const out = [];
    for (const group of groups) {
        const members = entries.filter(e => e.group === group.id);
        if (members.length === 0)
            continue;
        out.push({ header: group.title, count: members.length });
        for (const entry of members)
            out.push(entry);
    }
    return out;
}

// How many entries each group has (for the filter chips).
function counts(entries) {
    const n = {};
    for (const entry of entries)
        n[entry.group] = (n[entry.group] ?? 0) + 1;
    return n;
}
