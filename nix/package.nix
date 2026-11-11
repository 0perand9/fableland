# The daemon and the shell as they are: Quickshell and the programs the daemon
# runs are expected in the environment (wrapped.nix brings them along).
{
  lib,
  rustPlatform,
  pkg-config,
  sqlite,
  qt6,
}:

rustPlatform.buildRustPackage {
  pname = "fableland-unwrapped";
  version = (lib.importTOML ../daemon/Cargo.toml).package.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../daemon/Cargo.toml
      ../daemon/Cargo.lock
      ../daemon/features.json
      ../daemon/src
      ../shell
      ../assets
    ];
  };
  cargoRoot = "daemon";
  buildAndTestSubdir = "daemon";
  cargoLock.lockFile = ../daemon/Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ sqlite ];

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
