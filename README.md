# CNC Pi - NixOS Configuration for Raspberry Pi 4 B

✅ **Status: Deployed and Working** (Feb 25, 2026)

This repository contains a modular NixOS configuration for a Raspberry Pi 4 Model B, designed for CNC machine control. The Pi is currently running NixOS and accessible via SSH.

## Quick Info

- **Hostname**: `cnc-pi` (accessible at `cnc-pi.local`)
- **System**: NixOS 25.11 on Raspberry Pi 4
- **Network**: Ethernet-only (WiFi/Bluetooth disabled)
- **User**: `vandal`
- **Deployment Method**: nvmd pre-built installer (no building required!)

## 🚀 Getting Started

**First time deploying?** → Read **[FINAL-DEPLOYMENT.md](FINAL-DEPLOYMENT.md)** for complete step-by-step instructions.

**Quick overview:**
```bash
# 1. Download pre-built installer (no building!)
just download-installer

# 2. Flash to SD card
just flash-sd ./result/sd-image/*.img.zst /dev/sda

# 3. Boot Pi, get password from screen

# 4. Deploy your config
just deploy-to-installer cnc-pi root@<pi-ip>

# 5. SSH in after reboot
ssh vandal@cnc-pi.local
```

That's it! See [FINAL-DEPLOYMENT.md](FINAL-DEPLOYMENT.md) for detailed instructions with troubleshooting.

---

## 📁 Repository Structure

```
.
├── flake.nix                    # Main flake configuration
├── hosts/
│   └── cnc-pi/                  # Host-specific configuration
│       ├── configuration.nix    # Main system config (EDIT THIS)
│       └── hardware-configuration.nix
├── modules/
│   ├── nixos/                   # NixOS system modules
│   │   ├── packages.nix         # System packages (add CNC tools here)
│   │   └── services.nix         # System services
│   └── hardware/                # Hardware-specific modules
├── justfile                     # Task automation commands
└── FINAL-DEPLOYMENT.md          # Complete deployment guide
```

**Main files to edit:**
- `hosts/cnc-pi/configuration.nix` - System settings, networking, users
- `modules/nixos/packages.nix` - Add CNC software packages here
- `modules/nixos/services.nix` - Configure system services

---

## ✨ Features

- **No Building Required**: Uses pre-built nvmd installer images
- **Fully Declarative**: Everything configured in Nix
- **Modular Configuration**: Organized like a typical NixOS flake
- **Raspberry Pi 4 Support**: Uses official `nixos-raspberrypi` flake (nvmd)
- **Ethernet Networking**: DHCP-enabled, accessible via `cnc-pi.local`
- **SSH Access**: Remote management from your laptop
- **Serial Port Access**: User in `dialout` group for CNC communication
- **Minimal Attack Surface**: WiFi/Bluetooth disabled (can enable later)
- **Task Automation**: Many `just` commands for common operations

---

## 🛠️ Common Tasks

### Deploy Configuration Changes

**From your laptop:**
```bash
# Edit configuration
vim hosts/cnc-pi/configuration.nix

# Check for errors
just check

# Deploy to Pi
just deploy cnc-pi vandal@cnc-pi.local
```

**On the Pi itself:**
```bash
# SSH into Pi
ssh vandal@cnc-pi.local

# Clone flake (first time only)
cd ~
git clone <repo-url> cnc-pi-flake

# Rebuild system
cd ~/cnc-pi-flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

### Update System Packages

```bash
# Update flake inputs (get newer package versions)
just init

# Deploy updated system
just deploy cnc-pi vandal@cnc-pi.local
```

### Add CNC Software

Edit `modules/nixos/packages.nix`:

```nix
environment.systemPackages = with pkgs; [
  # Existing packages...
  
  # Add your CNC tools:
  # linuxcnc
  # openscad
  # freecad
  # grbl
];
```

Then deploy: `just deploy cnc-pi vandal@cnc-pi.local`

### View All Available Commands

```bash
just list
```

---

## 🔧 Prerequisites

**Hardware:**
- Raspberry Pi 4 Model B
- MicroSD card (32GB+, we use Samsung 128GB)
- Ethernet cable
- Power supply
- Monitor + keyboard (needed once for initial setup)

**Software:**
- Nix or NixOS on your development machine
- [just](https://github.com/casey/just) task runner (optional but recommended)
- Git for version control

---

## 📚 Documentation

- **[FINAL-DEPLOYMENT.md](FINAL-DEPLOYMENT.md)** - 🌟 **START HERE** - Complete deployment guide from scratch
- **[QUICKSTART-ETHERNET.md](QUICKSTART-ETHERNET.md)** - Quick reference for ethernet-only setup
- **[NEXT-STEPS.md](NEXT-STEPS.md)** - What to do after flashing SD card
- **[justfile](justfile)** - All available automation commands

### Old Documentation

Archived documentation from earlier approaches is in `old-material/` - kept for reference but not recommended.

---

## 🔐 Security & Access

**Current setup:**
- SSH enabled with password authentication
- Firewall: Only port 22 (SSH) open
- No root login via SSH
- WiFi/Bluetooth disabled

**Recommended next steps:**
1. Set up SSH keys: `ssh-copy-id vandal@cnc-pi.local`
2. Disable password auth (edit `configuration.nix`)
3. Keep system updated regularly

---

## 🌐 Network Configuration

**Current: Ethernet-only**
```nix
networking.useDHCP = lib.mkDefault true;
networking.interfaces.eth0.useDHCP = lib.mkDefault true;
networking.wireless.enable = false;
hardware.bluetooth.enable = false;
```

**To enable WiFi later:** Uncomment the WiFi section in `hosts/cnc-pi/configuration.nix` (around line 40).

---

## 🐛 Troubleshooting

### Can't SSH into Pi
```bash
# Check if Pi is on network
ping cnc-pi.local

# Or find Pi's IP
sudo nmap -sn <your-subnet>

# Try IP address instead of hostname
ssh vandal@<pi-ip-address>
```

### Configuration errors
```bash
# Always check before deploying
just check

# This validates your config without deploying
```

### Want to start over
Just re-flash the SD card and deploy again! That's the beauty of declarative configs.

See [FINAL-DEPLOYMENT.md](FINAL-DEPLOYMENT.md) for detailed troubleshooting.

---

## 🚢 Deployment Architecture

**The nvmd Approach (What We Use):**

1. **Pre-built installer** - Download from nvmd cache (no building!)
2. **Flash to SD card** - Boot Pi with this installer
3. **Deploy your config** - Push your custom NixOS configuration
4. **Reboot** - Pi runs your configuration forever after

**Benefits:**
- No cross-compilation needed
- No building on your machine
- Fast and reliable
- Well-tested by nvmd community

**Alternative approaches** (disko, custom images, etc.) are archived in `old-material/`.

---

## 📦 What's Installed

**Base system:**
- NixOS 25.11 (unstable)
- Raspberry Pi 4 kernel and firmware
- SSH server
- Avahi/mDNS for `.local` hostname resolution
- Tailscale (enabled but not configured)

**Utilities:**
- vim, git, htop, curl, wget, tmux

**To add more:** Edit `modules/nixos/packages.nix`

---

## 🎯 Project Goals

This Pi is intended for:
- **CNC machine control** (LinuxCNC, GRBL, etc.)
- **PLC communication** via Ethernet
- **Serial/USB device interfacing** (user in `dialout` group)
- **Reliable, declarative system** that can be rebuilt anytime

---

## 🙏 Credits

- **[nvmd/nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi)** - Excellent Pi support for NixOS
- **[NixOS](https://nixos.org/)** - The best Linux distribution
- **[just](https://github.com/casey/just)** - Task automation made easy

---

## 📝 State Version

**IMPORTANT**: The `system.stateVersion` is set to `25.05`. Do not change this after initial deployment! It ensures system compatibility across updates.

---

## 🤝 Contributing

This is a personal configuration, but feel free to:
- Use it as a template for your own Pi projects
- Submit issues if you find problems
- Share improvements via pull requests

---

## 📄 License

This configuration is provided as-is for educational and personal use.

---

## 🔗 Quick Links

- [Flake definition](flake.nix)
- [Main configuration](hosts/cnc-pi/configuration.nix)
- [Package list](modules/nixos/packages.nix)
- [Task commands](justfile)
- [Complete deployment guide](FINAL-DEPLOYMENT.md)

---

**Last Updated:** Feb 25, 2026  
**Status:** ✅ Deployed and operational  
**Hostname:** cnc-pi.local  
**NixOS Version:** 25.11.20260223.2597cb7
