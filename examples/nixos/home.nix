# /etc/nixos/home.nix — your user's desktop: Hyprland and Fableland.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.fableland.homeModules.default ];

  # CHANGE "alice" to your user name, in both places.
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "26.05"; # leave this as it is, also after updates

  # Programs for your user. kitty is the terminal SUPER + Return opens.
  home.packages = with pkgs; [
    kitty
    firefox
  ];

  # Hyprland, configured by hyprland.lua next to this file.
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # installed by programs.hyprland in configuration.nix
    portalPackage = null;
    configType = "lua";
    extraConfig = builtins.readFile ./hyprland.lua;
  };

  programs.fableland = {
    enable = true;

    # Settings fixed here win over the Settings popup; anything else can be
    # changed there. The full list is in Fableland's docs/PROTOCOL.md.
    settings = {
      terminal = "kitty";
    };

    # Parts you don't want can be switched off:
    # features.weather = false;

    # Plugins: add the inputs you uncommented in flake.nix.
    plugins = [
      # inputs.fable-movies
      # inputs.fable-arr
      # inputs.fable-crypto
    ];
  };
}
