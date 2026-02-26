# Cross-Compilation Setup for ARM Builds

Since the Raspberry Pi uses ARM (aarch64) architecture and most development machines use x86_64, you need to set up cross-compilation to build ARM packages.

## Method 1: Download Pre-built Installer (Fastest)

The easiest way is to just download the pre-built installer from the binary cache:

```bash
just download-installer
```

This pulls the already-built installer image without building anything locally. However, this only works for the official installer - you'll still need cross-compilation for building your custom configurations.

## Method 2: Enable binfmt Emulation (Recommended)

This allows your x86_64 system to build ARM packages using QEMU emulation.

### If Using NixOS

Add to your NixOS configuration (`/etc/nixos/configuration.nix` or modular config):

```nix
{
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"  # 64-bit ARM (Raspberry Pi 3, 4, 5)
  ];
}
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

### If Using Nix on Another OS (macOS, Linux)

Add to your `~/.config/nix/nix.conf`:

```
extra-platforms = aarch64-linux
```

And ensure binfmt is set up (on Linux):
```bash
# Install qemu-user-static if not already installed
# On Ubuntu/Debian:
sudo apt-get install qemu-user-static

# On Arch:
sudo pacman -S qemu-user-static-binfmt
```

## Method 3: Remote Builder

For the best performance, set up a remote ARM builder (like another Raspberry Pi or ARM server).

Add to your `~/.config/nix/nix.conf`:

```
builders = ssh://builder@arm-machine aarch64-linux /path/to/ssh/key 4 1 kvm,benchmark,big-parallel
```

## Verification

After setup, verify cross-compilation works:

```bash
# Should succeed without errors
nix eval --expr 'builtins.currentSystem'

# Try building a simple ARM package
nix build --system aarch64-linux nixpkgs#hello
```

## Building Your Configuration

Once cross-compilation is set up, you can:

```bash
# Build your custom configuration
just build

# Build SD card image with your configuration
just build-image

# Build the installer (slower with emulation)
just build-installer
```

## Performance Notes

- **Emulated builds are slower**: 3-10x slower than native builds
- **First build takes longest**: Subsequent builds use the binary cache
- **Use binary cache**: The nixos-raspberrypi cache has many pre-built packages
- **Consider remote builder**: If you build frequently, a remote ARM builder is much faster

## Troubleshooting

### "required system or feature not available"

This means binfmt emulation isn't active. Verify:

```bash
# On NixOS, check if configured:
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

# Should show QEMU configuration, not "No such file"
```

### Builds still fail with binfmt enabled

Try adding `--impure` flag (needed for some upstream flakes):

```bash
nix build --impure github:nvmd/nixos-raspberrypi#installerImages.rpi4
```

Or just use `just download-installer` to pull from cache instead.
