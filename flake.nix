{
  description = "NixOS configuration for Raspberry Pi 4 B - CNC Pi";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Raspberry Pi support
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Binary cache for nixos-raspberrypi
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-raspberrypi,
      home-manager,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        cnc-pi = nixos-raspberrypi.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit inputs;
            inherit nixos-raspberrypi;
          };
          modules = [
            # Raspberry Pi 4 hardware modules
            nixos-raspberrypi.nixosModules.raspberry-pi-4.base
            nixos-raspberrypi.nixosModules.raspberry-pi-4.display-vc4

            # Home Manager integration
            home-manager.nixosModules.home-manager

            # Host-specific configuration
            ./hosts/cnc-pi/configuration.nix

            # Custom modules
            ./modules/nixos

            # Platform settings
            {
              nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
            }
          ];
        };
      };
    };
}
