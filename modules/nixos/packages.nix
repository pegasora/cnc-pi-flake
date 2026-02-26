{
  config,
  pkgs,
  lib,
  ...
}: {
  # System-wide packages for CNC Pi
  environment.systemPackages = with pkgs; [
    # Essential tools
    neovim
    git
    htop
    btop
    curl
    wget
    rsync
    nh
    nurl
    python3
    networkmanager
    tailscale
    gh
    fzf
    fastfetch
    just
    devenv

    # Network tools
    tcpdump
    nmap
    iperf3

    # Development tools
    gcc
    gnumake
    python3

    # File management
    tree
    ripgrep
    fd
    bat
    eza

    # System utilities
    usbutils
    pciutils
    lshw

    # Add CNC-specific packages here as needed
  ];
}
