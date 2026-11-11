# The daemon and the shell with the plugins chosen, as they are: Quickshell and
# the programs the daemon runs are expected in the environment (wrapped.nix
# brings them along).
#
#   plugins   names of plugins in plugins/, or plugin folders from anywhere
#             (nix/plugins.nix resolves the other ways of naming one)
{
  lib,
  rustPlatform,
  pkg-config,
  jq,
  sqlite,
  qt6,
  plugins ? [ "movies" ],
}:

let
  # A name stays a name; a folder becomes its store path.
  sources = map (plugin: if lib.isString plugin then plugin else "${plugin}") plugins;
in
rustPlatform.buildRustPackage {
  pname = "fableland-unwrapped";
  version = (lib.importTOML ../daemon/Cargo.toml).package.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../daemon/Cargo.toml
      ../daemon/features.json
      ../daemon/src
      ../daemon/api
      ../daemon/plugin-set
      ../plugins
      ../shell
      ../assets
    ];
  };
  cargoLock.lockFile = ../Cargo.lock;
  buildAndTestSubdir = "daemon";

  nativeBuildInputs = [
    pkg-config
    jq
  ];
  buildInputs = [ sqlite ];

  # The plugins of this build (a plugin from elsewhere is copied into plugins/).
  postPatch = ''
    patchShebangs plugins/assemble
    plugins/assemble --copy ${if sources == [ ] then "--none" else lib.escapeShellArgs sources}
  '';
  # Cargo.lock lists the plugins of the repository's own build; this one may
  # have others. Their code may only use crates the lock already holds (those of
  # fable-plugin), so nothing needs downloading.
  preBuild = ''
    cargo metadata --offline --format-version 1 >/dev/null
  '';

  # The daemon looks for the shell in ../share/fableland next to its binary.
  # The backdrop patterns are GLSL; Qt loads them compiled.
  postInstall = ''
    mkdir -p $out/share/fableland
    cp -r shell assets $out/share/fableland/
    for shader in $out/share/fableland/shell/widgets/backdrop/*.frag; do
      QT_QPA_PLATFORM=offscreen ${qt6.qtshadertools}/bin/qsb --glsl "100 es,120,150" -o $shader.qsb $shader
    done
  '';

  meta = {
    description = "A Quickshell desktop shell for Hyprland, driven by a single daemon";
    mainProgram = "fable";
    platforms = lib.platforms.linux;
  };
}
