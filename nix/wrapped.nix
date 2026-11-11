# Fableland ready to run: `fable` with Quickshell and the programs of its
# features on PATH — appended, so the versions in your profile win. A feature
# that is switched off brings nothing:
#
#   fableland.override { features.movies = false; features.capture = false; }
#
# This only decides what is installed; what is switched on is a setting
# (`features` in settings.json, or managed.json — which the Home Manager module
# writes from the same option).
{
  lib,
  pkgs,
  symlinkJoin,
  makeWrapper,
  fableland-unwrapped,
  features ? { },
}:

let
  # Text is read off the screen in English, the language tesseract takes when
  # it is told none. Left to itself, nixpkgs brings every language: a gigabyte.
  tesseract = pkgs.tesseract.override { enableLanguages = [ "eng" ]; };

  # Programs by the feature that runs them. A name this nixpkgs does not have
  # is left out, and the daemon says what is missing when it is asked for it.
  tools = {
    always = [
      "wl-clipboard" # copying
      "pulseaudio" # pactl: volume and devices (works with PipeWire)
      "libxkbcommon" # xkbcli: the list of keyboard layouts
    ];
    wallpaper = [
      (if pkgs ? awww then "awww" else "swww")
      "mpvpaper" # video wallpapers ...
      "ffmpeg" # ... and their thumbnails
    ];
    palette = [ "matugen" ];
    clipboard = [ "cliphist" ];
    capture = [
      "grim"
      "wf-recorder"
      "satty" # annotating
      tesseract # reading text
      "zbar" # reading QR codes
    ];
    updates = [ "git" ];
  };
  # Every feature is on unless `features` says otherwise; colours are taken from the wallpaper.
  on = feature: features.${feature} or true;
  wanted = lib.filterAttrs (feature: _: on feature && (feature != "palette" || on "wallpaper")) tools;
  programs = lib.filter (program: program != null) (
    map (tool: if lib.isString tool then pkgs.${tool} or null else tool) (
      lib.concatLists (lib.attrValues wanted)
    )
  );

  # Quickshell finds the Qt modules it was built with; the shell also imports
  # QtMultimedia, to preview video wallpapers.
  quickshell = symlinkJoin {
    name = "quickshell-with-multimedia";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/quickshell \
        --prefix QML_IMPORT_PATH : ${pkgs.qt6.qtmultimedia}/lib/qt-6/qml \
        --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins
    '';
  };
in
symlinkJoin {
  pname = "fableland";
  inherit (fableland-unwrapped) version;
  paths = [ fableland-unwrapped ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/fable --suffix PATH : ${lib.makeBinPath ([ quickshell ] ++ programs)}
  '';
  # For running the shell from a source tree, as dev/window does.
  passthru = { inherit quickshell; };
  meta = fableland-unwrapped.meta;
}
