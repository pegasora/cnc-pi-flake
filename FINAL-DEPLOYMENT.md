# Complete Deployment Guide - From Nothing to Running Pi

This is the complete, tested procedure to get NixOS running on your Raspberry Pi 4 using the nvmd approach.

## What You Need

### Hardware
- Raspberry Pi 4 Model B
- SD card (32GB+, we used Samsung 128GB)
- Ethernet cable
- Power supply for Pi
- **Monitor and keyboard** (needed once to get installer password)

### Software
- Your development machine with Nix/NixOS (the one you're on now)
- This flake repository

---

## Part 1: Initial Deployment (One-Time Setup)

### Step 1: Download Pre-built Installer

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Download official nvmd installer (no building required!)
just download-installer
```

**Time**: 2-5 minutes depending on internet speed

---

### Step 2: Flash SD Card

**Find your SD card device:**

```bash
# List storage devices
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|NAME"
```

Look for your SD card (will show as ~119GB for 128GB card).

**Flash the installer:**

```bash
# Replace /dev/sdX with YOUR device (e.g., /dev/sda)
just flash-sd ./result/sd-image/nixos-installer-rpi4-uboot.img.zst /dev/sda
```

The command will:
- Auto-unmount any mounted partitions
- Decompress the .zst file on-the-fly
- Flash to SD card
- Ask for confirmation before writing

**Time**: 5-10 minutes

**Safely eject:**

```bash
sudo eject /dev/sda
```

---

### Step 3: Boot Pi and Get Installer Password

1. **Insert SD card** into Raspberry Pi
2. **Connect monitor and keyboard** to Pi (you'll need this to see the password!)
3. **Connect ethernet cable** to Pi
4. **Connect power** to Pi

**Wait 60-90 seconds for boot**

**On the monitor**, you'll see:
- NixOS installer splash screen
- Network information (IP address, hostname)
- **SSH credentials with a randomly generated password**

**Write down**:
- IP address (e.g., `10.8.4.27`)
- Root password (it's randomly generated)

You can disconnect the monitor/keyboard after this - you won't need them again!

---

### Step 4: Find Pi on Network (Alternative to Monitor)

If you couldn't connect a monitor, find the Pi's IP:

```bash
# Try mDNS first
ping nixos.local

# Or scan your network
sudo nmap -sn <your-subnet>
# Example: sudo nmap -sn 10.8.4.0/24
```

Look for Raspberry Pi MAC addresses: `b8:27:eb`, `dc:a6:32`, `e4:5f:01`

**Note**: You'll still need the password shown on screen, so monitor is recommended.

---

### Step 5: Deploy Your Configuration

From your development machine:

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Deploy to the installer
# Replace with your Pi's IP address
just deploy-to-installer cnc-pi root@10.8.4.27
```

**What happens:**
1. Builds your NixOS configuration locally (on your laptop)
2. Copies it to the Pi via SSH
3. Installs it as the boot configuration
4. Reboots the Pi

**Time**: 5-10 minutes

You'll be prompted for the root password (the one from the screen).

**Output you'll see:**
```
Building configuration locally...
Copying configuration to Pi...
Installing on Pi...
System installed! Rebooting Pi...
Pi is rebooting. Wait 60 seconds, then connect:
  ssh vandal@cnc-pi.local
```

---

### Step 6: Verify Deployment

Wait 60-90 seconds for the Pi to reboot with your configuration.

**Connect via SSH:**

```bash
# Try mDNS hostname
ssh vandal@cnc-pi.local

# Or use IP address
ssh vandal@10.8.4.27
```

**Username**: `vandal`  
**Password**: Your hashed password from configuration.nix

**If you get in successfully - YOU'RE DONE!** 🎉

---

### Step 7: Verify System

Once logged in:

```bash
# Check hostname and version
hostname
# Should show: cnc-pi

nixos-version
# Should show: 25.11.something

# Check network
ip addr show
# Should show eth0 with IP address

# Check services
systemctl status

# Check disk usage
df -h
```

Everything should show your custom configuration!

---

## Part 2: Managing the Flake on the Pi

Now that your Pi is running, you want to manage it like your main NixOS system.

### Option A: Clone Flake Directly on Pi (Recommended)

```bash
# SSH into the Pi
ssh vandal@cnc-pi.local

# Clone your flake to home directory
cd ~
git clone <your-repo-url> cnc-pi-flake
# Or if you're using a local directory, copy it over:
# scp -r ~/Projects/flakes/cnc-pi-flake vandal@cnc-pi.local:~/

# Enter the directory
cd ~/cnc-pi-flake

# Rebuild system using local flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

This way, the Pi manages its own configuration just like your main system.

### Option B: Keep Managing from Your Laptop (Simpler)

You can keep the flake on your laptop and deploy remotely:

```bash
# From your laptop
cd ~/Projects/flakes/cnc-pi-flake

# Make changes to configuration.nix
vim hosts/cnc-pi/configuration.nix

# Deploy changes
just deploy cnc-pi vandal@cnc-pi.local
```

This is easier for making changes but requires your laptop to deploy.

### Recommended: Hybrid Approach

1. **Clone flake to Pi** (for Pi to rebuild itself)
2. **Keep copy on laptop** (for remote management)
3. **Use git** to sync changes between them

```bash
# On Pi
cd ~/cnc-pi-flake
git pull  # Get latest changes
sudo nixos-rebuild switch --flake .#cnc-pi

# Or from laptop
cd ~/Projects/flakes/cnc-pi-flake
git push  # Push your changes
just deploy cnc-pi vandal@cnc-pi.local  # Deploy remotely
```

---

## Part 3: Next Steps After Deployment

### 1. Set Up SSH Keys (Highly Recommended)

```bash
# From your laptop
ssh-copy-id vandal@cnc-pi.local

# Test passwordless login
ssh vandal@cnc-pi.local
# Should log in without password!
```

**Then disable password authentication:**

Edit `hosts/cnc-pi/configuration.nix`:

```nix
services.openssh.settings.PasswordAuthentication = false;
```

Redeploy:

```bash
# From laptop
just deploy cnc-pi vandal@cnc-pi.local

# Or from Pi
cd ~/cnc-pi-flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

### 2. Add to Git (If Not Already)

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Initialize git if not done
git init
git add .
git commit -m "Initial NixOS Pi configuration"

# Optional: push to remote
git remote add origin <your-repo-url>
git push -u origin main
```

### 3. Add CNC Software Packages

Edit `modules/nixos/packages.nix`:

```nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    tmux
    
    # Add your CNC tools here:
    # linuxcnc
    # openscad
    # freecad
    # grbl
    # etc.
  ];
}
```

Then redeploy to apply changes.

### 4. Configure for CNC/PLC

Your user `vandal` is already in the `dialout` group for serial port access!

Test serial ports:

```bash
ssh vandal@cnc-pi.local
ls -la /dev/ttyUSB*  # USB serial devices
ls -la /dev/ttyAMA*  # GPIO serial
```

### 5. Enable WiFi Later (If Needed)

WiFi configuration is commented out in `configuration.nix`. To enable:

1. Edit `hosts/cnc-pi/configuration.nix`
2. Uncomment the WiFi section
3. Update SSID/password for your network
4. Redeploy

---

## Troubleshooting

### Can't SSH after deployment

**Check hostname:**
```bash
# After deployment, hostname changed to cnc-pi.local
ssh vandal@cnc-pi.local

# If that doesn't work, use IP
ssh vandal@10.8.4.27
```

**Pi might still be booting:**
- Wait another 30-60 seconds
- Check monitor if connected (red/green LEDs)

**Network changed:**
- Pi might have gotten new IP via DHCP
- Scan network again: `sudo nmap -sn <subnet>`

### Want to re-deploy from scratch

Just re-flash the SD card and start from Step 2!

### Forgot vandal password

The password is hashed in `configuration.nix`. To reset:

1. Edit `hosts/cnc-pi/configuration.nix`
2. Uncomment `initialPassword` line and set new password
3. Comment out `hashedPassword` line
4. Redeploy
5. SSH in with new password
6. Run `passwd` to set permanent password
7. Update config with new hashed password (get from `/etc/shadow`)

### Configuration errors before deployment

Always check configuration before deploying:

```bash
cd ~/Projects/flakes/cnc-pi-flake
just check
```

This validates your config without building/deploying.

---

## Quick Reference Commands

### Deployment Commands

```bash
# From laptop - deploy changes
just deploy cnc-pi vandal@cnc-pi.local

# From Pi - rebuild locally
cd ~/cnc-pi-flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

### Update System

```bash
# Update flake inputs (get newer packages)
cd ~/cnc-pi-flake
nix flake update

# Or use justfile
just init

# Then rebuild
sudo nixos-rebuild switch --flake .#cnc-pi
```

### Remote Management

```bash
# SSH into Pi
ssh vandal@cnc-pi.local

# Check system status
just status  # (from laptop)
ssh vandal@cnc-pi.local "systemctl status"

# View system info
just sysinfo  # (from laptop)

# Tail logs
just logs  # (from laptop)
ssh vandal@cnc-pi.local "journalctl -f"
```

### Cleanup

```bash
# Remove old generations (free up space)
ssh vandal@cnc-pi.local
sudo nix-collect-garbage -d
sudo nix-store --optimise

# Or use justfile on Pi
cd ~/cnc-pi-flake
just clean
```

---

## File Structure Reference

```
~/cnc-pi-flake/              # Flake directory (on Pi)
├── flake.nix               # Main flake configuration
├── flake.lock              # Locked dependency versions
├── hosts/
│   └── cnc-pi/
│       ├── configuration.nix       # Main system config
│       └── hardware-configuration.nix
├── modules/
│   ├── nixos/
│   │   ├── default.nix
│   │   ├── packages.nix    # System packages (EDIT THIS)
│   │   └── services.nix    # System services
│   └── hardware/
│       └── default.nix
├── justfile                # Task runner commands
└── *.md                    # Documentation
```

**Main files to edit:**
- `hosts/cnc-pi/configuration.nix` - System settings
- `modules/nixos/packages.nix` - Add packages here
- `modules/nixos/services.nix` - Configure services

---

## Success Checklist

After deployment, verify:

- [ ] Can SSH to `vandal@cnc-pi.local` ✓
- [ ] Hostname shows `cnc-pi` ✓
- [ ] Ethernet has IP address ✓
- [ ] Can become root with `sudo` ✓
- [ ] Serial ports accessible (if needed)
- [ ] SSH keys set up (recommended)
- [ ] Flake cloned to Pi's `~/cnc-pi-flake/`
- [ ] Can rebuild locally on Pi
- [ ] CNC software installed (as needed)

---

## Summary: Complete Workflow

**One-time deployment:**
1. Download installer: `just download-installer`
2. Flash SD card: `just flash-sd <image> /dev/sda`
3. Boot Pi with monitor to get password
4. Deploy: `just deploy-to-installer cnc-pi root@<pi-ip>`
5. Wait for reboot
6. SSH in: `ssh vandal@cnc-pi.local`

**Daily usage:**
```bash
# Make changes
vim hosts/cnc-pi/configuration.nix

# Deploy from laptop
just deploy cnc-pi vandal@cnc-pi.local

# Or rebuild on Pi
ssh vandal@cnc-pi.local
cd ~/cnc-pi-flake
sudo nixos-rebuild switch --flake .#cnc-pi
```

**That's it!** You now have a fully functional, declarative NixOS system on your Pi! 🚀

---

## Tips

- **Keep backups** of your working configuration in git
- **Test changes** with `just check` before deploying
- **Use generations** - NixOS keeps old configs, can rollback anytime
- **Document changes** in git commits for future reference
- **Monitor resources** - Pi 4 has limited RAM, watch `htop`

Enjoy your CNC Pi setup! 🛠️
