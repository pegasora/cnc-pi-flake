{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  # Hostname
  networking.hostName = "cnc-pi";

  # Ethernet-only networking (for CNC/PLC communication and remote access)
  networking.useDHCP = lib.mkDefault true;
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  # Disable WiFi and Bluetooth (for security and simplicity)
  networking.wireless.enable = false;
  hardware.bluetooth.enable = false;

  # WiFi Configuration (COMMENTED OUT - Enable later if needed)
  # To enable WiFi later, uncomment the section below:
  #
  # networking.networkmanager = {
  #   enable = true;
  #   wifi.backend = "wpa_supplicant";
  # };
  #
  # networking.wireless.enable = lib.mkForce false;
  #
  # # Pre-configure WiFi network for auto-connection to "NILE ROBOT"
  # networking.networkmanager.ensureProfiles.profiles = {
  #   nile-robot = {
  #     connection = {
  #       id = "NILE ROBOT";
  #       type = "wifi";
  #       autoconnect = true;
  #       autoconnect-priority = 100;
  #     };
  #     wifi = {
  #       ssid = "NILE ROBOT";
  #       mode = "infrastructure";
  #     };
  #     wifi-security = {
  #       key-mgmt = "wpa-psk";
  #       psk = "12345678";
  #     };
  #     ipv4 = {
  #       method = "auto"; # DHCP
  #     };
  #     ipv6 = {
  #       method = "auto";
  #     };
  #   };
  # };

  # Time zone
  time.timeZone = "America/Los_Angeles";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  # groups
  users.groups.vandal = { };

  # Users
  users.users.vandal = {
    isNormalUser = true;
    description = "Default user";
    extraGroups = [
      "wheel"
      "networkmanager"
      "dialout" # For serial/USB device access (CNC machines)
      "tty"
    ];
    #initialPassword = "vandal";
    hashedPassword = "$6$YLE5/JajmGU.PYs.$MM6ASYVM7Ms.0v7iUQ2khS.XeIP9Y7GDmkpaEuoUMDz3efLErnZAeYptdWIpljGhzY4LbuOHqh7/B.Gaoi6G4.";
    shell = pkgs.bash;
    group = "vandal";
  };

  # SSH for remote access on zero trust network
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # Change to false after SSH key setup
      KbdInteractiveAuthentication = false;
    };
  };

  # Firewall - allow SSH only (zero trust network will handle approval)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    tmux
  ];

  # Allow unfree packages if needed
  nixpkgs.config.allowUnfree = true;

  # Enable hardware graphics (for display if connected)
  hardware.graphics.enable = true;

  # System state version - DO NOT CHANGE after installation
  system.stateVersion = "25.05";
}
