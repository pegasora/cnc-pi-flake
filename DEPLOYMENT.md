# Quick Deployment Guide

## Pre-Deployment Checklist

- [ ] Raspberry Pi 4 B with MicroSD card (16GB+)
- [ ] Ethernet cable connected to zero trust network
- [ ] Development machine with Nix/NixOS
- [ ] This repository cloned/created
- [ ] (Optional) [just](https://github.com/casey/just) command runner installed

## Quick Start with Just (Recommended)

If you have `just` installed, deployment is simple:

```bash
cd ~/Projects/flakes/cnc-pi-flake

# 1. Initialize and validate
just init          # Update flake lock
just check         # Validate configuration

# 2. Build installer image
just build-installer

# 3. Flash to SD card
just flash-sd ./result/sd-image/*.img /dev/sdX

# 4. Boot Pi, note IP address, then deploy
just deploy-anywhere cnc-pi root@<pi-ip>

# 5. Post-deployment setup
just ssh-copy-id
just ssh
# Then change password: passwd
```

See `just list` for all available commands.

## Quick Start (Manual Method)

### 1. Initialize the Flake

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Update flake.lock with actual versions
nix flake update

# Check that the configuration builds
nix flake check
```

### 2. Build the Installer Image

```bash
# Build the official RPi4 installer from nixos-raspberrypi
nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4

# Flash to SD card (replace /dev/sdX with your SD card device)
sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot the Raspberry Pi

1. Insert SD card into Raspberry Pi
2. Connect ethernet cable
3. Power on the Pi
4. Note the IP address shown on screen (or scan network)

Default credentials will be displayed on screen if using the installer image.

### 4. Deploy Your Configuration

```bash
# Option A: Using nixos-anywhere (fully automated)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#cnc-pi \
  --target-host root@<pi-ip-address>

# Option B: Manual deployment (if already running NixOS)
nixos-rebuild switch \
  --flake .#cnc-pi \
  --target-host root@<pi-ip-address> \
  --use-remote-sudo
```

### 5. Post-Deployment

```bash
# SSH into the Pi
ssh cnc@cnc-pi.local

# Change the default password
passwd

# On your dev machine, copy your SSH key
ssh-copy-id cnc@cnc-pi.local
```

### 6. Disable Password Authentication

Edit `hosts/cnc-pi/configuration.nix`:
```nix
services.openssh.settings.PasswordAuthentication = false;
```

Rebuild:
```bash
nixos-rebuild switch --flake .#cnc-pi --target-host cnc@cnc-pi.local
```

### 7. Approve on Zero Trust Network

Use your network's approval mechanism to whitelist the Pi's MAC/IP address.

## Alternative: Build SD Image Directly

If you want to build a ready-to-use SD card image with your configuration:

```bash
# Build the SD image (requires aarch64 support via binfmt or native builder)
nix build .#nixosConfigurations.cnc-pi.config.system.build.sdImage

# Flash it
sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Note: This requires cross-compilation or an aarch64 builder configured in your nix settings.

## Updating the System

### Using Just Commands:
```bash
# From development machine
just init                              # Update flake
just deploy cnc-pi cnc@cnc-pi.local   # Deploy changes

# On the Pi itself
just update-rebuild   # Update and rebuild
```

### Manual Method:

#### From Development Machine:
```bash
cd ~/Projects/flakes/cnc-pi-flake
nix flake update
nixos-rebuild switch --flake .#cnc-pi --target-host cnc@cnc-pi.local
```

#### On the Pi:
```bash
cd /path/to/cnc-pi-flake
git pull
sudo nixos-rebuild switch --flake .#cnc-pi
```

## Troubleshooting

### Can't find the Pi on the network
```bash
# Scan your network for the Pi
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"

# Or use avahi/mdns
ping cnc-pi.local
```

### Build fails on development machine
```bash
# Make sure you have the binary cache configured
cat <<EOF >> ~/.config/nix/nix.conf
extra-substituters = https://nixos-raspberrypi.cachix.org
extra-trusted-public-keys = nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=
EOF
```

### SSH connection issues
```bash
# Check if SSH is running on the Pi (if you have display/keyboard access)
systemctl status sshd

# Check firewall rules
sudo nft list ruleset
```

## Network Configuration Notes

The configuration is set up for:
- **Ethernet only** (no WiFi)
- **DHCP** on eth0
- **mDNS** enabled (accessible at `cnc-pi.local`)
- **Firewall** enabled with only SSH (port 22) open
- **No Bluetooth** (disabled for security)

This aligns with your zero trust network requirements where you'll approve the device separately.

## Adding CNC Software

When you're ready to add CNC-specific software:

1. Create a new module: `modules/nixos/cnc.nix`
2. Add it to `modules/nixos/default.nix` imports
3. Install packages like LinuxCNC, grbl, etc.
4. Configure serial/USB permissions in the module

Example:
```nix
# modules/nixos/cnc.nix
{ config, pkgs, lib, ... }: {
  # Add CNC software
  environment.systemPackages = with pkgs; [
    # Add CNC packages here
  ];
  
  # Grant user access to serial devices
  users.users.cnc.extraGroups = [ "dialout" "tty" ];
}
```
