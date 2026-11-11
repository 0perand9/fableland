-- Fableland in a Hyprland Lua config (~/.config/hypr/hyprland.lua).

-- One process to start: the daemon. It starts the shell itself, restarts it if
-- it crashes, and replaces every helper the old setup launched by hand
-- (wallpaper daemon, clipboard watchers, focus tracker, volume listener, ...).
hl.on("hyprland.start", function()
  hl.exec_cmd("fable daemon")
end)

-- Lets a restarted shell take the lock screen back over instead of leaving
-- the session stuck on a dead lock.
hl.config({ misc = { allow_session_lock_restore = true } })

-- Keybinds talk to the daemon through Hyprland's own event socket, so a key
-- press does not even spawn a process.
local function fable(command)
  return hl.dsp.event("fable " .. command)
end

hl.bind("SUPER + SHIFT + Return", fable("toggle launcher"))
hl.bind("SUPER + V",              fable("toggle clipboard"))
hl.bind("SUPER + ALT + W",        fable("toggle wallpaper"))
hl.bind("SUPER + SHIFT + D",      fable("toggle focus"))
hl.bind("SUPER + N",              fable("toggle control"))
hl.bind("SUPER + SHIFT + M",      fable("toggle monitors"))
hl.bind("SUPER + F1",             fable("toggle guide"))
hl.bind("SUPER + L",              fable("lock"))
hl.bind("SUPER + ALT + D",        fable("toggle quick draw"))   -- draw on the screen

hl.bind("SUPER + S",              fable("capture region"))
hl.bind("SUPER + SHIFT + S",      fable("capture record"))
hl.bind("Print",                  fable("capture full"))

hl.bind("XF86AudioRaiseVolume",   fable("volume +5"),      { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",   fable("volume -5"),      { repeating = true, locked = true })
hl.bind("XF86AudioMute",          fable("volume mute"),    { locked = true })
hl.bind("XF86AudioMicMute",       fable("mic mute"),       { locked = true })
hl.bind("XF86MonBrightnessUp",    fable("brightness +5"),  { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown",  fable("brightness -5"),  { repeating = true, locked = true })
hl.bind("XF86AudioPlay",          fable("media play-pause"), { locked = true })
hl.bind("XF86AudioNext",          fable("media next"),     { locked = true })
hl.bind("XF86AudioPrev",          fable("media prev"),     { locked = true })

-- The same commands work from a terminal or a script: `fable toggle launcher`.
-- Keybinds can also be managed from Settings → Keybinds; those are applied by
-- the daemon at runtime and need nothing in this file.
