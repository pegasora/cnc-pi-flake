{
  config,
  pkgs,
  lib,
  ...
}: {
  # System services configuration

  # Enable automatic updates (optional - comment out if you want manual control)
  # system.autoUpgrade = {
  #   enable = true;
  #   flake = "/home/cnc/cnc-pi-flake";
  #   flags = [
  #     "--update-input" "nixpkgs"
  #     "--commit-lock-file"
  #   ];
  # };

  # Periodic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Optimize nix store periodically
  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };

  # Enable avahi for mDNS (helps find Pi on network)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };

  # tailscale for remote access
  services.tailscale.enable = true;
}
