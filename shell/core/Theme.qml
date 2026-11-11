pragma Singleton
import QtQuick
import Quickshell

// Colours, fonts, sizes and motion shared by the whole shell.
//
// Sizes: the UI is designed in "design units" — pixels on a 1920x1080 screen —
// and `Theme.px(n)` converts them to real pixels for the current screen and the
// user's UI scale. Every literal length goes through px(); hairlines stay 1.
Singleton {
    id: root

    // ── scale ────────────────────────────────────────────────────────────
    readonly property real scale: autoScale * Math.max(0.5, Math.min(2.5, Daemon.setting("uiScale", 1)))
    // Bigger screens get bigger UI, but less than proportionally.
    readonly property real autoScale: {
        const screen = Quickshell.screens[0];
        if (!screen)
            return 1;
        const r = Math.min(screen.width / 1920, screen.height / 1080);
        return r <= 1 ? Math.max(0.35, Math.pow(r, 0.85)) : Math.pow(r, 0.5);
    }

    function px(n) {
        return Math.round(n * scale);
    }

    // ── fonts ────────────────────────────────────────────────────────────
    readonly property string font: firstInstalled(["JetBrainsMono Nerd Font", "JetBrains Mono", "Iosevka Nerd Font", "monospace"])
    readonly property string iconFont: firstInstalled(["Symbols Nerd Font", "JetBrainsMono Nerd Font", "Iosevka Nerd Font", "monospace"])

    function firstInstalled(families) {
        const installed = Qt.fontFamilies();
        for (const f of families)
            if (installed.indexOf(f) >= 0)
                return f;
        return families[families.length - 1];
    }

    // ── palette ──────────────────────────────────────────────────────────
    // Published by the daemon (generated from the wallpaper); Catppuccin Mocha until then.
    readonly property var fallback: ({
            base: "#1e1e2e", crust: "#11111b", mantle: "#181825",
            surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
            text: "#cdd6f4", subtext: "#a6adc8", dim: "#6c7086", faint: "#45475a",
            primary: "#cba6f7", onPrimary: "#11111b", secondary: "#b4befe", tertiary: "#f5c2e7", error: "#f38ba8",
            mode: "dark", generated: false
        })
    property var palette: fallback
    readonly property bool dark: palette.mode !== "light"

    // Backgrounds, darkest first.
    readonly property color base: tone("base")
    readonly property color crust: tone("crust")
    readonly property color mantle: tone("mantle")
    // Raised surfaces: cards, hovered rows, pressed rows.
    readonly property color surface0: tone("surface0")
    readonly property color surface1: tone("surface1")
    readonly property color surface2: tone("surface2")
    // Text, strongest first.
    readonly property color text: tone("text")
    readonly property color subtext: tone("subtext")
    readonly property color dim: tone("dim")
    readonly property color faint: tone("faint")
    // The accent and its companions.
    readonly property color accent: tone("primary")
    readonly property color accentText: tone("onPrimary")
    readonly property color secondary: tone("secondary")
    readonly property color tertiary: tone("tertiary")
    readonly property color error: tone("error")

    // Named hues for things with a fixed meaning (volume is peach, network is blue, ...).
    // With a generated palette they lean towards the accent so nothing clashes.
    readonly property color red: hue("#f38ba8", "#d20f39")
    readonly property color peach: hue("#fab387", "#fe640b")
    readonly property color yellow: hue("#f9e2af", "#df8e1d")
    readonly property color green: hue("#a6e3a1", "#40a02b")
    readonly property color teal: hue("#94e2d5", "#179299")
    readonly property color sapphire: hue("#74c7ec", "#209fb5")
    readonly property color blue: hue("#89b4fa", "#1e66f5")
    readonly property color mauve: hue("#cba6f7", "#8839ef")
    readonly property color pink: hue("#f5c2e7", "#ea76cb")

    readonly property color border: alpha(text, 0.08)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.45 : 0.25)

    function hue(onDark, onLight) {
        const c = Qt.color(dark ? onDark : onLight);
        if (!palette.generated || accent.hslSaturation < 0.08)
            return c;
        // Turn the hue a little towards the accent (at most 15°), keeping its character.
        let turn = accent.hslHue - c.hslHue;
        if (turn > 0.5)
            turn -= 1;
        else if (turn < -0.5)
            turn += 1;
        const shifted = c.hslHue + Math.max(-15 / 360, Math.min(15 / 360, turn * 0.5));
        return Qt.hsla((shifted + 1) % 1, c.hslSaturation, c.hslLightness, 1);
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // The colour that goes with a weather condition published by the daemon.
    function weatherColor(condition) {
        switch (condition) {
        case "clear-day": case "storm": return yellow;
        case "clear-night": return mauve;
        case "partly-day": return peach;
        case "rain": return sapphire;
        case "fog": return blue;
        case "snow": return text;
        default: return subtext;
        }
    }

    // A new palette (new wallpaper) fades in from whatever is on screen.
    property var fadeFrom: fallback
    property real fade: 1

    function tone(key) {
        const to = Qt.color(palette[key] ?? fallback[key]);
        return fade >= 1 ? to : mix(Qt.color(fadeFrom[key] ?? fallback[key]), to, fade);
    }

    function adopt(next) {
        const shown = {};
        for (const key in fallback)
            shown[key] = typeof fallback[key] === "string" && key !== "mode" ? String(tone(key)) : palette[key];
        fadeFrom = shown;
        palette = next ?? fallback;
        // The very first palette just appears.
        if (Daemon.ready)
            fadeIn.restart();
    }

    Connections {
        target: Daemon

        function onThemeChanged() {
            root.adopt(Daemon.theme);
        }
    }

    NumberAnimation {
        id: fadeIn

        target: root
        property: "fade"
        from: 0
        to: 1
        duration: root.slow
    }

    // ── shape ────────────────────────────────────────────────────────────
    readonly property int radius: px(14)        // cards, bar groups
    readonly property int radiusSmall: px(10)   // rows, buttons, fields
    readonly property int radiusLarge: px(22)   // popups
    readonly property int gap: px(8)            // between related things
    readonly property int pad: px(16)           // inside cards
    readonly property int barHeight: px(48)
    readonly property int barMargin: px(8)
    // Height the bar reserves at the top of each screen.
    readonly property int barZone: barHeight + barMargin

    // ── motion (ms) ──────────────────────────────────────────────────────
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int slow: 400
}
