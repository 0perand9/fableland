{
  description = "Fableland — a Quickshell desktop shell for Hyprland, driven by a single daemon";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEach = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # fableland            ready to run: with Quickshell and the programs of its features
      # fableland-unwrapped  the daemon and the shell alone; the rest comes from your environment
      # Both come with the movies plugin; `.override { plugins = [ … ]; }` chooses others.
      packages = forEach (pkgs: rec {
        fableland-unwrapped = pkgs.callPackage ./nix/package.nix { };
        fableland = pkgs.callPackage ./nix/wrapped.nix { inherit fableland-unwrapped; };
        default = fableland;
      });

      overlays.default = final: _: {
        fableland-unwrapped = final.callPackage ./nix/package.nix { };
        fableland = final.callPackage ./nix/wrapped.nix { };
      };

      # programs.fableland: the package, its plugins, which features are on, and settings to fix.
      homeModules.default = ./nix/home-module.nix;

      devShells = forEach (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [ cargo rustc rustfmt clippy gcc sway grim python3 jq qt6.qtshadertools ];
        };
      });
    };
}
