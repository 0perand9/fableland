-- Hyprland with Fableland: a small starting point. home.nix reads this file;
-- after a change, rebuild and Hyprland reloads it.
--
-- SUPER is the Windows key. SUPER + F1 shows every keybind, including the
-- ones you add later in Fableland's Settings → Keybinds (those need nothing here).

-- Every monitor at its best mode, side by side. Fableland's Displays popup
-- (SUPER + SHIFT + M) arranges them properly and remembers it.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Start Fableland with Hyprland. It starts its shell and everything it needs
-- by itself. Its log: journalctl --user -t fableland
hl.on("hyprland.start", function()
  hl.exec_cmd("systemd-cat -t fableland fable daemon")
end)

-- A restarted shell may take the lock screen back over.
hl.config({ misc = { allow_session_lock_restore = true } })

local function key(k) return "SUPER + " .. k end
local function fable(command) return hl.dsp.event("fable " .. command) end

-- Fableland
hl.bind(key("SPACE"),          fable("toggle launcher"))   -- search and open apps
hl.bind(key("F1"),             fable("toggle guide"))      -- what everything does
hl.bind(key("N"),              fable("toggle control"))    -- notifications, power, brightness
hl.bind(key("V"),              fable("toggle clipboard"))
hl.bind(key("ALT + W"),        fable("toggle wallpaper"))
hl.bind(key("SHIFT + M"),      fable("toggle monitors"))
hl.bind(key("I"),              fable("toggle settings"))
hl.bind(key("L"),              fable("lock"))
hl.bind(key("S"),              fable("capture region"))    -- screenshot
hl.bind(key("SHIFT + S"),      fable("capture record"))    -- screen recording (again to stop)
hl.bind("Print",               fable("capture full"))

-- Apps and windows
hl.bind(key("Return"),         hl.dsp.exec_cmd("kitty"))
hl.bind(key("Q"),              hl.dsp.window.close())
hl.bind(key("F"),              hl.dsp.window.fullscreen())
hl.bind(key("T"),              hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("SHIFT + E"),      hl.dsp.exit())              -- log out

for _, dir in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(key(dir),            hl.dsp.focus({ direction = dir }))
  hl.bind(key("SHIFT + " .. dir), hl.dsp.window.move({ direction = dir }))
end

-- Workspaces: SUPER + 1…9 goes there, SUPER + SHIFT + 1…9 takes the window along.
for i = 1, 9 do
  hl.bind(key(tostring(i)),    hl.dsp.focus({ workspace = i }))
  hl.bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i }))
end

-- Mouse: SUPER + left drag moves a window, SUPER + right drag resizes it.
hl.bind(key("mouse:272"),      hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"),      hl.dsp.window.resize(), { mouse = true })

-- Volume, brightness and media keys
hl.bind("XF86AudioRaiseVolume",  fable("volume +5"),        { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",  fable("volume -5"),        { repeating = true, locked = true })
hl.bind("XF86AudioMute",         fable("volume mute"),      { locked = true })
hl.bind("XF86AudioMicMute",      fable("mic mute"),         { locked = true })
hl.bind("XF86MonBrightnessUp",   fable("brightness +5"),    { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", fable("brightness -5"),    { repeating = true, locked = true })
hl.bind("XF86AudioPlay",         fable("media play-pause"), { locked = true })
hl.bind("XF86AudioNext",         fable("media next"),       { locked = true })
hl.bind("XF86AudioPrev",         fable("media prev"),       { locked = true })
