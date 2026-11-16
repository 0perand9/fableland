# Coming from imperative-dots

Fableland grew out of the Quickshell setup in
[ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots). Its
daemon replaces everything that setup started by hand, so remove these from
your Hyprland autostart:

- the `quickshell -p …/Shell.qml` line
- `swww-daemon` and the lines that restore the wallpaper
- both `wl-paste --watch cliphist store` lines
- `focus_daemon.py` and `volume_listener.sh`
- the `matugen` call at start-up

Replace `qs_manager.sh toggle <x>` keybinds with `fable toggle <x>` (the old
popup names still work). `playerctld` is not needed. With hypridle, use
`lock_cmd = fable lock`, or drop hypridle and use Settings → Idle.

Your screen-time history and weather configuration are imported on first
start; the old files are left untouched.
