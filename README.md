# CNC Pi - NixOS Configuration for Raspberry Pi 4 B

This repository contains a modular NixOS configuration for a Raspberry Pi 4 Model B, designed for CNC machine control with zero trust network connectivity.

## Repository Structure

```
.
├── flake.nix                    # Main flake configuration
├── hosts/
│   └── cnc-pi/                  # Host-specific configuration
│       ├── configuration.nix    # Main system configuration
│       └── hardware-configuration.nix  # Hardware-specific settings
├── modules/
│   ├── nixos/                   # NixOS system modules
│   │   ├── default.nix
│   │   ├── packages.nix         # System packages
│   │   └── services.nix         # System services
│   └── hardware/                # Hardware-specific modules
│       └── default.nix
└── disks/                       # Disk partitioning configurations (optional)
```

## Features

- **Modular Configuration**: Organized similar to your main NixOS system
- **Raspberry Pi 4 Support**: Uses `nixos-raspberrypi` flake for hardware support
- **Zero Trust Network**: Configured for ethernet-only with firewall enabled
- **SSH Access**: Remote management via SSH
- **Minimal Attack Surface**: WiFi and Bluetooth disabled by default

## Prerequisites

1. Raspberry Pi 4 Model B
2. MicroSD card (16GB+ recommended) or USB drive
3. Ethernet connection to your zero trust network
4. Another machine with Nix/NixOS for building and deployment
5. (Optional) [just](https://github.com/casey/just) command runner for convenience

## Quick Start with Just

If you have [just](https://github.com/casey/just) installed, you can use convenient commands:

```bash
# See all available commands
just list

# Initialize (update flake lock)
just init

# Check configuration for errors
just check

# Build the installer image
just build-installer

# Deploy using nixos-anywhere
just deploy-anywhere cnc-pi root@<pi-ip>

# Or deploy to existing NixOS installation
just deploy cnc-pi cnc@cnc-pi.local

# SSH into the Pi
just ssh

# And many more... see: just list
```

See the [Using Just Commands](#using-just-commands) section below for details.

## Initial Setup

### Option 1: Using nixos-anywhere (Recommended)

This method will automatically partition, format, and install NixOS on your Raspberry Pi.

1. **Boot the Pi with the installer image**:
   
   Build the installer SD card image:
   ```bash
   nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4
   ```
   
   Flash it to an SD card:
   ```bash
   sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```

2. **Boot the Raspberry Pi** from the SD card and connect via ethernet

3. **Find the Pi's IP address** (it will show on screen, or use `nmap` to scan your network)

4. **Deploy from your development machine**:
   ```bash
   cd ~/Projects/flakes/cnc-pi-flake
   
   # Initialize git and flake (if not done already)
   git init
   git add .
   
   # Deploy to the Pi
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#cnc-pi \
     --target-host root@<pi-ip-address>
   ```

### Option 2: Manual Installation

1. **Build the SD card image**:
   ```bash
   cd ~/Projects/flakes/cnc-pi-flake
   nix build .#nixosConfigurations.cnc-pi.config.system.build.sdImage
   ```

2. **Flash the image**:
   ```bash
   sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```

3. **Boot the Pi** and SSH in to complete setup

### Option 3: Remote Deployment to Existing System

If you already have NixOS running on the Pi:

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Deploy configuration changes
nixos-rebuild switch --flake .#cnc-pi --target-host cnc@cnc-pi.local
```

## Post-Installation Setup

1. **Change the default password**:
   ```bash
   ssh cnc@cnc-pi.local
   passwd
   ```

2. **Set up SSH key authentication**:
   ```bash
   # On your development machine
   ssh-copy-id cnc@cnc-pi.local
   ```

3. **Disable password authentication** (edit `hosts/cnc-pi/configuration.nix`):
   ```nix
   services.openssh.settings.PasswordAuthentication = false;
   ```
   Then rebuild:
   ```bash
   nixos-rebuild switch --flake .#cnc-pi --target-host cnc@cnc-pi.local
   ```

4. **Approve on zero trust network**: Use your network's approval process to allow the Pi

## Network Configuration

The Pi is configured for ethernet-only connectivity:
- DHCP enabled on eth0
- WiFi disabled
- Bluetooth disabled
- Firewall enabled (SSH only)
- mDNS enabled (accessible at `cnc-pi.local`)

## Updating the System

### Update flake inputs:
```bash
nix flake update
```

### Rebuild and deploy:
```bash
nixos-rebuild switch --flake .#cnc-pi --target-host cnc@cnc-pi.local
```

### Or on the Pi itself:
```bash
cd /path/to/cnc-pi-flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

## Using Just Commands

This repository includes a `justfile` for convenient command execution. Here are the main commands:

### Setup and Validation
```bash
just init              # Update flake lock file
just check             # Validate configuration
just info              # Show flake info
just metadata          # Show flake metadata
```

### Building
```bash
just build             # Build the configuration
just build-image       # Build SD card image
just build-installer   # Build official installer image
```

### Deployment
```bash
just deploy cnc-pi cnc@cnc-pi.local           # Deploy to existing system
just deploy-anywhere cnc-pi root@192.168.1.100 # Fresh install with nixos-anywhere
just flash-sd ./result/sd-image/*.img /dev/sdX # Flash image to SD card
```

### Remote Management
```bash
just ssh                    # SSH into the Pi
just ssh-copy-id            # Copy SSH key to Pi
just status                 # Check system status
just sysinfo                # Show system info
just logs                   # Tail system logs
```

### Network Utilities
```bash
just scan-network           # Scan for Raspberry Pi on network
just ping-pi                # Ping the Pi via mDNS
```

### On the Pi Itself
```bash
just rebuild               # Rebuild current configuration
just update-rebuild        # Update and rebuild
just clean                 # Clean old generations and garbage collect
```

For a full list of commands, run:
```bash
just list
```

## Customization

### Adding Packages

Edit `modules/nixos/packages.nix` to add system packages.

### Adding Services

Edit `modules/nixos/services.nix` to configure system services.

### Hardware-Specific Configuration

Add custom hardware modules in `modules/hardware/` for:
- GPIO access
- Serial/USB device configuration
- CNC-specific interfaces (SPI, I2C, etc.)

### CNC Software

Add CNC-related packages and services in their own module files, for example:
- `modules/nixos/cnc/linuxcnc.nix`
- `modules/nixos/cnc/grbl.nix`

## Troubleshooting

### Can't connect to Pi after installation
- Check network cable connection
- Verify DHCP is working on your network
- Try accessing via IP address instead of hostname
- Check your zero trust network approval status

### SSH connection refused
- Ensure firewall port 22 is open
- Verify SSH service is running: `systemctl status sshd`

### Build failures
- Update flake inputs: `nix flake update`
- Clear nix cache if needed: `nix-collect-garbage -d`
- Check nixos-raspberrypi binary cache is accessible

## Binary Cache

This configuration uses the nixos-raspberrypi binary cache to speed up builds. The cache configuration is in `flake.nix`.

## Resources

- [nixos-raspberrypi repository](https://github.com/nvmd/nixos-raspberrypi)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)

## State Version

**IMPORTANT**: Do not change `system.stateVersion` after initial installation. It's set to `25.05` in `hosts/cnc-pi/configuration.nix`.
