# /etc/nixos/flake.nix — a NixOS system with Hyprland and Fableland.
#
# Copy this file, home.nix and hyprland.lua next to your configuration.nix,
# then change the two things marked CHANGE below. The README walks through it.
{
  inputs = {
    # Fableland needs Hyprland 0.57 or newer, which is on nixos-unstable.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fableland = {
      url = "github:0perand9/fableland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plugins (optional): uncomment the ones you want, and list them in home.nix.
    # fable-movies = { url = "github:0perand9/fable-movies"; flake = false; };
    # fable-arr = { url = "github:0perand9/fable-arr"; flake = false; };
    # fable-crypto = { url = "github:0perand9/fable-crypto"; flake = false; };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    {
      # "nixos" is the name you rebuild with: nixos-rebuild switch --flake /etc/nixos#nixos
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs; };
            # CHANGE "alice" to your user name (the one you log in with).
            home-manager.users.alice = import ./home.nix;
          }
        ];
      };
    };
}
