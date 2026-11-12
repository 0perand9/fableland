# Home Manager module: `programs.fableland`.
#
# Installs Fableland with the plugins chosen and the programs of the features
# that are on, and writes ~/.config/fableland/managed.json — the settings the
# daemon treats as fixed.
# Starting the daemon is left to the Hyprland configuration (see the README).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.fableland;
  json = pkgs.formats.json { };
  # The one list of features, shared with the daemon: name → what it is.
  features = lib.importJSON ../daemon/features.json;
in
{
  options.programs.fableland = {
    enable = lib.mkEnableOption "Fableland, a desktop shell for Hyprland";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The daemon and the shell, without the programs they use. Built again with {option}`plugins`.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "What is installed: {option}`package` with the plugins, Quickshell and the programs of the features that are on.";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.path
          lib.types.package
          (lib.types.attrsOf lib.types.anything)
        ]
      );
      default = [ ];
      example = lib.literalExpression ''
        [
          inputs.fable-movies                    # a flake input (flake = false is enough)
          ./my-plugin                            # a folder
          { github = "someone/fable-weather2"; rev = "3f9c2e1…"; hash = "sha256-…"; }
          { src = inputs.more; dir = "plugins/x"; runtimeInputs = [ pkgs.jq ]; }
        ]
      '';
      description = ''
        The plugins compiled into Fableland (see docs/PLUGINS.md). Each is
        named by its folder, or by its name when it is in Fableland's plugins/:
        a path, a flake input, a package, `{ github, rev, hash }` to fetch one
        pinned by its hash, or `{ src }`. The last two also take `dir`, a
        subfolder, and `runtimeInputs`, programs the plugin runs. A plugin's
        settings are under its name in {option}`settings`; one in the list can
        still be switched off at runtime as the feature named after it.
      '';
    };

    features = lib.mapAttrs (
      name: about:
      lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = about;
      }
    ) features;

    settings = lib.mkOption {
      type = json.type;
      default = { };
      example = lib.literalExpression ''
        {
          terminal = "kitty";
          workspaceCount = 10;
          wallpaper.dir = "~/Pictures/Wallpapers";
          arr.sonarr = { url = "http://localhost:8989"; apiKeyFile = "/run/secrets/sonarr"; };
          keybinds = [
            { keys = "SUPER + V"; action = "fable"; command = "toggle clipboard"; }
          ];
        }
      '';
      description = ''
        Settings to fix. What is set here wins over the Settings popup, which
        shows it as set by the system configuration; everything else stays
        changeable there. The keys are those of settings.json, listed in
        docs/PROTOCOL.md.
      '';
    };

    fonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the font the shell draws its text and icons with (JetBrainsMono Nerd Font).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fableland.finalPackage = pkgs.callPackage ./wrapped.nix {
      fableland-unwrapped = cfg.package;
      inherit (cfg) features plugins;
    };

    home.packages = [ cfg.finalPackage ] ++ lib.optional cfg.fonts pkgs.nerd-fonts.jetbrains-mono;
    fonts.fontconfig.enable = lib.mkIf cfg.fonts true;

    # The daemon notices when this file is replaced: settings apply at once, and
    # for a change of features it restarts itself.
    xdg.configFile."fableland/managed.json".source = json.generate "fableland-managed.json" (
      lib.recursiveUpdate cfg.settings { inherit (cfg) features; }
    );
  };
}
