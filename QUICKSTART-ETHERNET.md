# Quick Start - Ethernet Only Deployment

## Your Setup
- **Raspberry Pi 4 Model B** for CNC control
- **Samsung 128GB SD cards** (you have 2 new ones)
- **Network**: Ethernet only (WiFi disabled)
- **Goal**: Deploy NixOS fully remotely from your laptop

## What You'll Get
After deployment, your Pi will:
- Connect via Ethernet (DHCP)
- Be accessible via SSH at `cnc-pi.local`
- Have WiFi/Bluetooth disabled for security
- Run your custom NixOS configuration

---

## Step 1: Download Pre-built Installer

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Download official nvmd installer from binary cache (no building!)
just download-installer
```

**Time**: 2-5 minutes depending on internet speed

---

## Step 2: Identify Your SD Card

**IMPORTANT**: Get the correct device name to avoid data loss!

```bash
# List all storage devices
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|NAME"
```

Your Samsung 128GB card will show as:
- Device: `/dev/sdb` or `/dev/sdc` (or similar)
- Size: ~119GB (formatting overhead)
- Vendor/Model: Should show Samsung

**Write down the device name** - you'll need it next!

---

## Step 3: Flash SD Card

```bash
# Replace /dev/sdX with YOUR actual device (e.g., /dev/sdb)
just flash-sd ./result/sd-image/*.img /dev/sdX
```

⚠️ **CRITICAL**: Triple-check the device name!
- Wrong device = you could wipe your laptop's drive!
- The script will ask for confirmation

**Time**: 5-10 minutes

---

## Step 4: Boot the Pi

1. **Insert SD card** into Raspberry Pi 4
2. **Connect ethernet cable** to Pi and your network
3. **Connect power** to Pi
4. **Wait 60 seconds** for boot

**What to look for**:
- Red LED = solid (power good)
- Green LED = blinking/on (system activity)

---

## Step 5: Find the Pi's IP Address

### Option A: Try mDNS hostname first (easiest)

```bash
ping nixos.local
```

If this works, you can skip to Step 6 using `nixos.local`!

### Option B: Scan your network

```bash
# Find your network subnet first
ip addr show

# Then scan (replace with your actual subnet)
sudo nmap -sn 192.168.1.0/24
# or
sudo nmap -sn 10.0.0.0/24
```

Look for:
- Hostname containing "nixos" or "raspberry"
- MAC address starting with: `b8:27:eb`, `dc:a6:32`, or `e4:5f:01`

### Option C: Check your router/DHCP server

Your network's admin interface should show "nixos" or the Pi's MAC address.

**Write down the IP address!**

---

## Step 6: Deploy Your Configuration

This is the magic step - it does everything automatically!

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Deploy using nixos-anywhere
# Replace <pi-ip> with the actual IP or use nixos.local
just deploy-anywhere cnc-pi root@<pi-ip>

# Examples:
just deploy-anywhere cnc-pi root@192.168.1.100
# or
just deploy-anywhere cnc-pi root@nixos.local
```

**What happens**:
1. Connects to installer via SSH
2. Partitions and formats the SD card
3. Installs NixOS with your configuration
4. Configures user, SSH, firewall, services
5. Reboots the Pi automatically

**Time**: 10-20 minutes

You'll see lots of output scrolling by - this is normal! It's downloading and installing packages.

☕ Grab a coffee while it works!

---

## Step 7: Verify Deployment

After the Pi reboots (~1 minute), SSH in as your user:

```bash
# Try mDNS hostname first
ssh vandal@cnc-pi.local

# Or use IP if you have it
ssh vandal@<pi-ip>
```

**Password**: Your hashed password from configuration.nix

If you get in successfully, **you're done!** 🎉

Check the system:

```bash
# Check NixOS version
nixos-version

# Check network
ip addr show

# Check running services
systemctl status

# Check uptime
uptime
```

---

## You're Done! 🎉

Your Pi is now:
- ✅ Running your custom NixOS configuration
- ✅ Connected via Ethernet (DHCP)
- ✅ Accessible at `cnc-pi.local`
- ✅ SSH enabled for user `vandal`
- ✅ WiFi/Bluetooth disabled (can enable later if needed)
- ✅ Ready for CNC/PLC work!

---

## Troubleshooting

### Can't find Pi on network

**Check the basics**:
```bash
# Is Pi getting power? (red LED on?)
# Is network cable connected properly? (green LED activity?)
# Wait a full 2 minutes after power-on, then try again
```

**Try scanning again**:
```bash
sudo nmap -sn <your-subnet>
```

**Check your network**:
- Is the Pi on the same network/VLAN as your laptop?
- Does your school network block device discovery?
- Try connecting Pi directly to your laptop with ethernet cable

### SSH connection refused

Wait 30 more seconds - SSH might still be starting.

Try with explicit user:
```bash
ssh root@nixos.local  # On installer
ssh vandal@cnc-pi.local  # After deployment
```

### nixos-anywhere deployment fails

**Connection issues**:
```bash
# Test SSH first
ssh root@<pi-ip>

# If SSH works, try deployment again
```

**Already deployed?**:
If you already deployed once, use regular deployment instead:
```bash
just deploy cnc-pi vandal@cnc-pi.local
```

### Want to re-deploy from scratch

Just re-flash the SD card and start over from Step 3!

---

## Next Steps

### 1. Set Up SSH Keys (Recommended)

```bash
# From your laptop
ssh-copy-id vandal@cnc-pi.local

# Test passwordless login
ssh vandal@cnc-pi.local

# Then disable password auth
# Edit hosts/cnc-pi/configuration.nix:
#   services.openssh.settings.PasswordAuthentication = false;

# Redeploy
just deploy cnc-pi vandal@cnc-pi.local
```

### 2. Add CNC Software Packages

Edit `modules/nixos/packages.nix` to add tools you need:

```nix
environment.systemPackages = with pkgs; [
  # Your existing packages...
  
  # Add CNC-related packages:
  # linuxcnc
  # openscad
  # freecad
  # grbl
];
```

Then deploy:
```bash
just deploy cnc-pi vandal@cnc-pi.local
```

### 3. Configure Serial/GPIO Access

Your user is already in the `dialout` group for serial ports!

Test serial port access:
```bash
ssh vandal@cnc-pi.local
ls -la /dev/ttyUSB*  # USB serial devices
ls -la /dev/ttyAMA*  # GPIO serial
```

### 4. Enable WiFi Later (If Needed)

The WiFi configuration is commented out in `configuration.nix`.

To enable it:
1. Edit `hosts/cnc-pi/configuration.nix`
2. Uncomment the WiFi section
3. Adjust SSID/password as needed
4. Redeploy: `just deploy cnc-pi vandal@cnc-pi.local`

### 5. Update the System

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Update flake inputs (get latest packages)
just init

# Check for issues
just check

# Deploy updates
just deploy cnc-pi vandal@cnc-pi.local
```

---

## Quick Reference Commands

```bash
# SSH into Pi
ssh vandal@cnc-pi.local

# Deploy configuration changes
just deploy cnc-pi vandal@cnc-pi.local

# Update system
just init && just deploy cnc-pi vandal@cnc-pi.local

# Check configuration for errors
just check

# View system status remotely
just status

# View system info remotely  
just sysinfo

# Tail system logs remotely
just logs
```

---

## Configuration Files

- **Main config**: `hosts/cnc-pi/configuration.nix`
- **System packages**: `modules/nixos/packages.nix`
- **System services**: `modules/nixos/services.nix`
- **Flake definition**: `flake.nix`

All configuration is declarative - edit files, then redeploy!

---

## Getting Help

- **Project docs**: See `README.md`, `DEPLOYMENT.md`, `AGENTS.md`
- **nvmd docs**: https://github.com/nvmd/nixos-raspberrypi
- **NixOS manual**: https://nixos.org/manual/nixos/stable/

Ready to start? Run the first command:

```bash
cd ~/Projects/flakes/cnc-pi-flake
just download-installer
```
