# Quick Start Deployment Guide

## Your Setup
- **Raspberry Pi 4 Model B** for CNC control
- **Samsung 128GB SD cards** (you have 2 new ones)
- **Network**: "NILE ROBOT" WiFi + Ethernet for PLC communication
- **Goal**: Deploy NixOS fully remotely from your laptop

## What You'll Get
After deployment, your Pi will:
- Auto-connect to "NILE ROBOT" WiFi on boot
- Have ethernet available for CNC/PLC communication
- Be accessible via SSH for remote management
- Run your custom NixOS configuration

---

## Step 1: Download Pre-built Installer (No Building!)

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Download official nvmd installer from binary cache
just download-installer
```

**What this does**: Downloads a pre-built, tested installer image (~1-2GB) from nvmd's cache. No compilation needed!

**Time**: 2-5 minutes depending on internet speed

---

## Step 2: Flash SD Card

**First, identify your SD card:**

```bash
# See all storage devices
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|NAME"
```

Look for your Samsung 128GB card. It will show as something like:
- `/dev/sdb` or `/dev/sdc` 
- Size will be ~119GB (due to formatting)

**Then flash the installer:**

```bash
# Replace /dev/sdX with YOUR device (e.g., /dev/sdb)
just flash-sd ./result/sd-image/*.img /dev/sdX
```

⚠️ **CRITICAL**: Double-check the device name! Wrong device = data loss!

The script will ask for confirmation. Type `y` to proceed.

**Time**: 5-10 minutes

---

## Step 3: Boot Pi with Ethernet

1. **Insert SD card** into Raspberry Pi 4
2. **Connect ethernet cable** (temporarily - just for deployment)
3. **Connect power** to Pi
4. **Wait 30-60 seconds** for boot

**What's happening**: The installer is booting. It has SSH enabled and will get an IP via DHCP.

---

## Step 4: Find the Pi on Network

You need to find the Pi's IP address. Here are your options:

### Option A: Scan the network

```bash
# Replace with your school's subnet
sudo nmap -sn <subnet>

# Examples:
# sudo nmap -sn 192.168.1.0/24
# sudo nmap -sn 10.0.0.0/24
```

Look for "Raspberry Pi" or check MAC addresses starting with:
- `b8:27:eb` (older Pi)
- `dc:a6:32` (Pi 4)
- `e4:5f:01` (Pi 4)

### Option B: Try mDNS hostname

```bash
ping nixos.local
```

If this works, you can use `nixos.local` as the hostname.

### Option C: Check your router's DHCP lease table

Your network admin interface should show connected devices.

---

## Step 5: Deploy Your Configuration

Once you have the Pi's IP (or hostname), deploy your custom config:

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Deploy using nixos-anywhere
# Replace <pi-ip> with actual IP or use nixos.local
just deploy-anywhere cnc-pi root@<pi-ip>

# Examples:
# just deploy-anywhere cnc-pi root@192.168.1.100
# just deploy-anywhere cnc-pi root@nixos.local
```

**What this does**:
1. Connects to the installer via SSH
2. Partitions and formats the SD card
3. Installs NixOS with YOUR configuration
4. Configures WiFi auto-connect to "NILE ROBOT"
5. Sets up user `vandal`, SSH, firewall, etc.
6. Reboots automatically

**Time**: 10-20 minutes

You'll see lots of output. This is normal! It's installing packages and configuring the system.

---

## Step 6: Verify WiFi Auto-Connect

After deployment completes and Pi reboots (~1 minute):

```bash
# Unplug ethernet cable from Pi
# Wait 30 seconds for WiFi to connect

# SSH in via WiFi (using mDNS)
ssh vandal@cnc-pi.local

# Or by IP if you know it
ssh vandal@<wifi-ip>
```

**Password**: Your hashed password from configuration.nix

**If WiFi isn't working**, plug ethernet back in and check:

```bash
ssh vandal@cnc-pi.local
nmcli device status
nmcli connection show
```

---

## Step 7: You're Done! 🎉

Your Pi is now:
- ✅ Running your custom NixOS configuration
- ✅ Auto-connecting to "NILE ROBOT" WiFi on boot
- ✅ Accessible via SSH (`vandal@cnc-pi.local`)
- ✅ Has ethernet available for CNC/PLC communication
- ✅ Fully declarative and reproducible

---

## Common Issues & Solutions

### Can't find Pi on network after installer boot

**Check**: Are both LEDs on?
- Red LED = Power (should be solid)
- Green LED = Activity (should blink or be on)

**Try**:
```bash
# Wait a full 2 minutes, then scan again
sudo nmap -sn <subnet>

# Try pinging
ping nixos.local
```

**If still not found**: Check if ethernet cable is properly connected. Try a different cable.

### nixos-anywhere deployment fails

**Common causes**:
1. **Wrong IP/hostname**: Double-check the IP address
2. **SSH not ready**: Wait 30 more seconds and retry
3. **Network timeout**: Check firewall on your school network

**Try**:
```bash
# Test SSH connection first
ssh root@<pi-ip>
# If this works, try deployment again
```

### WiFi not auto-connecting after deployment

**Check WiFi status**:
```bash
ssh vandal@cnc-pi.local  # via ethernet
nmcli device wifi list
nmcli connection show
```

**Manually connect once** (it should auto-connect after):
```bash
nmcli device wifi connect "NILE ROBOT" password 12345678
```

**Then reboot**:
```bash
sudo reboot
```

### Want both WiFi and Ethernet active simultaneously

Your config already supports this! NetworkManager will manage WiFi, and ethernet will work independently. Both can be active at the same time.

---

## Next Steps

### Set up SSH keys (recommended)

```bash
# From your laptop
ssh-copy-id vandal@cnc-pi.local

# Then disable password auth in configuration.nix:
# services.openssh.settings.PasswordAuthentication = false;

# Redeploy
just deploy cnc-pi vandal@cnc-pi.local
```

### Add CNC-specific software

Edit `modules/nixos/packages.nix` to add packages you need:
- LinuxCNC
- GRBL tools
- G-code senders
- etc.

Then redeploy:
```bash
just deploy cnc-pi vandal@cnc-pi.local
```

### Configure GPIO/Serial/USB access

Your user is already in the `dialout` group for serial port access!

For GPIO, you may need additional configuration in `configuration.nix`.

### Update the system

```bash
# Update flake inputs
cd ~/Projects/flakes/cnc-pi-flake
just init

# Rebuild and deploy
just deploy cnc-pi vandal@cnc-pi.local
```

---

## Configuration Files Reference

- **Main config**: `hosts/cnc-pi/configuration.nix`
- **Packages**: `modules/nixos/packages.nix`
- **Services**: `modules/nixos/services.nix`
- **Flake**: `flake.nix`

All changes are declarative - edit files, then redeploy!

---

## Need Help?

1. Check the detailed guides:
   - `README.md` - Comprehensive documentation
   - `DEPLOYMENT.md` - Deployment details
   - `AGENTS.md` - Project context

2. Check nvmd docs:
   - https://github.com/nvmd/nixos-raspberrypi

3. Test configuration before deploying:
   ```bash
   just check
   ```
