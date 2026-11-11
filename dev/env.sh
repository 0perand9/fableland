# Shared by the dev scripts: everything the sandbox daemon reads or writes lives
# under .sandbox/home, so development never touches your real configuration.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export FABLE_HOME="$ROOT/.sandbox/home"
export FABLE_SOCK="$FABLE_HOME/run/fable.sock"
FABLE_BIN="$ROOT/target/debug/fable"
# The shell the dev scripts show; set FABLE_SHELL to try another copy of it.
FABLE_SHELL=${FABLE_SHELL:-$ROOT/shell}

# What the shell is tried out with (dev/shot, dev/window) comes from PATH, or
# from Nix — built once, its store path remembered in .sandbox/<name>.
find_program() {
    local name=$1 installable=$2 cached="$ROOT/.sandbox/$1"
    command -v "$name" && return
    # Built again when the remembered path was garbage-collected.
    [ -x "$(cat "$cached" 2>/dev/null)/bin/$name" ] || { mkdir -p "$ROOT/.sandbox"; nix build "$installable" --no-link --print-out-paths >"$cached"; }
    echo "$(cat "$cached")/bin/$name"
}

# sway, the compositor the shell is tried out in.
find_sway() {
    find_program sway nixpkgs#sway
}

# Quickshell as the flake's package runs it: with the Qt modules the shell imports.
find_quickshell() {
    find_program quickshell "$ROOT#fableland.quickshell"
}

# The backdrop patterns are GLSL, and Qt only loads shaders compiled to .qsb.
# Compiles those that are missing or older than their sources.
build_shaders() {
    local dir="$FABLE_SHELL/widgets/backdrop" stale=() shader
    for shader in "$dir"/*.frag; do
        [ "$shader.qsb" -nt "$shader" ] && [ "$shader.qsb" -nt "$dir/common.glsl" ] || stale+=("$shader")
    done
    [ ${#stale[@]} -gt 0 ] || return 0
    local qsb=(qsb)
    command -v qsb >/dev/null || qsb=(nix shell nixpkgs#qt6.qtshadertools -c qsb)
    for shader in "${stale[@]}"; do
        "${qsb[@]}" --glsl "100 es,120,150" -o "$shader.qsb" "$shader"
    done
}
