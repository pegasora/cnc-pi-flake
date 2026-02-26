# Justfile for managing Raspberry Pi NixOS configuration
# Default host

default_host := "cnc-pi"

# List all available commands
list:
    @just --list

# Initialize: Update flake lock file
init:
    nix flake update

# Check the flake configuration for errors
check:
    nix flake check

# Clean all the NixOS configurations
clean:
    nh clean all

# switch using nh, will auto-detect hostname
switch:
    nh os switch .

# update flakes
update:
    nix flake update

################################################################################
# LEGACY, in case nh is not working
################################################################################

# Rebuild the NixOS configuration. Packages, services, etc. will be rebuilt.
switch-old host:
    sudo nixos-rebuild switch --flake "./#{{ host }}"

# Update flakes and rebuild the NixOS configuration
update-full-old host:
    nix flake update
    sudo nixos-rebuild switch --flake "./#{{ host }}"

# Build the configuration (doesn't deploy)
build host=default_host:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Build the SD card image for Raspberry Pi
build-image host=default_host:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.sdImage

# Deploy to Raspberry Pi using nixos-rebuild (requires existing NixOS on Pi)
deploy host=default_host target="":
    #!/usr/bin/env bash
    if [ -z "{{ target }}" ]; then
        echo "Usage: just deploy [host] <target-address>"
        echo "Example: just deploy cnc-pi root@192.168.1.100"
        echo "Example: just deploy cnc-pi cnc@cnc-pi.local"
        exit 1
    fi
    nixos-rebuild switch --flake .#{{ host }} --target-host {{ target }} --use-remote-sudo

# Deploy to installer (simpler method for nvmd installer)
deploy-to-installer host=default_host target="":
    #!/usr/bin/env bash
    if [ -z "{{ target }}" ]; then
        echo "Usage: just deploy-to-installer [host] <target-address>"
        echo "Example: just deploy-to-installer cnc-pi root@10.8.4.27"
        exit 1
    fi
    echo "Building configuration locally..."
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

    echo "Copying configuration to Pi..."
    nix copy --to ssh://{{ target }} ./result

    echo "Installing on Pi..."
    ssh {{ target }} "nix-env -p /nix/var/nix/profiles/system --set $(readlink ./result) && /nix/var/nix/profiles/system/bin/switch-to-configuration boot"

    echo "System installed! Rebooting Pi..."
    ssh {{ target }} "reboot"
    echo ""
    echo "Pi is rebooting. Wait 60 seconds, then connect:"
    echo "  ssh vandal@cnc-pi.local"

# Deploy using nixos-anywhere (fresh installation - requires disko)
deploy-anywhere host=default_host target="":
    #!/usr/bin/env bash
    if [ -z "{{ target }}" ]; then
        echo "Usage: just deploy-anywhere [host] <target-address>"
        echo "Example: just deploy-anywhere cnc-pi root@192.168.1.100"
        exit 1
    fi
    nix run github:nix-community/nixos-anywhere -- \
        --flake .#{{ host }} \
        --target-host {{ target }}

# Download the official nixos-raspberrypi installer image (from cache)
download-installer:
    nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4 --print-out-paths

# Build the official nixos-raspberrypi installer image locally (requires binfmt emulation)
build-installer:
    nix build github:nvmd/nixos-raspberrypi#installerImages.rpi4 --impure --print-out-paths

# Unmount all partitions on a device (useful before flashing)
unmount-device device="":
    #!/usr/bin/env bash
    if [ -z "{{ device }}" ]; then
        echo "Usage: just unmount-device <device>"
        echo "Example: just unmount-device /dev/sda"
        exit 1
    fi
    echo "Unmounting all partitions on {{ device }}..."
    sudo umount {{ device }}* 2>/dev/null || true
    echo "Done!"

# Decompress a .zst image file
decompress-image image="":
    #!/usr/bin/env bash
    if [ -z "{{ image }}" ]; then
        echo "Usage: just decompress-image <image.zst>"
        echo "Example: just decompress-image ./result/sd-image/nixos-*.img.zst"
        exit 1
    fi
    if [[ "{{ image }}" != *.zst ]]; then
        echo "Error: Image must be a .zst file"
        exit 1
    fi
    IMAGE="{{ image }}"
    OUTPUT="${IMAGE%.zst}"
    echo "Decompressing {{ image }} to $OUTPUT..."
    zstd -d "{{ image }}" -o "$OUTPUT"
    echo "Done! Decompressed image: $OUTPUT"

# Flash image to SD card (handles both .img and .img.zst)
flash-sd image="" device="":
    #!/usr/bin/env bash
    if [ -z "{{ image }}" ] || [ -z "{{ device }}" ]; then
        echo "Usage: just flash-sd <image-path> <device>"
        echo "Example: just flash-sd ./result/sd-image/nixos-*.img /dev/sdX"
        echo "Example: just flash-sd ./result/sd-image/nixos-*.img.zst /dev/sdX"
        echo ""
        echo "Available devices:"
        lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|NAME"
        exit 1
    fi

    # Check if device exists
    if [ ! -b "{{ device }}" ]; then
        echo "Error: {{ device }} is not a block device"
        exit 1
    fi

    # Unmount any mounted partitions
    echo "Unmounting partitions on {{ device }}..."
    sudo umount {{ device }}* 2>/dev/null || true

    echo "Flashing {{ image }} to {{ device }}..."
    echo "WARNING: This will erase all data on {{ device }}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if image is compressed
        if [[ "{{ image }}" == *.zst ]]; then
            echo "Decompressing and flashing..."
            zstdcat "{{ image }}" | sudo dd of={{ device }} bs=4M status=progress conv=fsync
        else
            echo "Flashing..."
            sudo dd if="{{ image }}" of={{ device }} bs=4M status=progress conv=fsync
        fi
        sync
        echo "Done! You can now eject {{ device }}"
    fi

# Update and rebuild (for running on the Pi itself)
rebuild host=default_host:
    sudo nixos-rebuild switch --flake .#{{ host }}

# Update flake and rebuild (for running on the Pi itself)
update-rebuild host=default_host:
    nix flake update
    sudo nixos-rebuild switch --flake .#{{ host }}

# Show the current system configuration
show-config host=default_host:
    nix eval .#nixosConfigurations.{{ host }}.config.system.nixos.label

# Show flake info
info:
    nix flake show

# Show flake metadata
metadata:
    nix flake metadata

# SSH into the Pi
ssh target="cnc@cnc-pi.local":
    ssh {{ target }}

# Copy SSH key to Pi
ssh-copy-id target="cnc@cnc-pi.local":
    ssh-copy-id {{ target }}

# Check Pi status via SSH
status target="cnc@cnc-pi.local":
    ssh {{ target }} "systemctl status"

# Show Pi system info
sysinfo target="cnc@cnc-pi.local":
    ssh {{ target }} "uname -a && free -h && df -h"

# Tail Pi system logs
logs target="cnc@cnc-pi.local":
    ssh {{ target }} "journalctl -f"

# Scan network for Raspberry Pi
scan-network subnet="192.168.1.0/24":
    @echo "Scanning {{ subnet }} for Raspberry Pi devices..."
    nmap -sn {{ subnet }} | grep -B 2 -i "raspberry\|b8:27:eb\|dc:a6:32\|e4:5f:01"

# Ping the Pi using mDNS
ping-pi hostname="cnc-pi.local":
    ping -c 4 {{ hostname }}
