# Next Steps After Flashing SD Card

## Current Status
✅ SD card successfully flashed with nvmd installer  
⏳ Ready to boot and deploy

---

## What to Do Next

### Step 1: Safely Eject SD Card

```bash
# Eject the SD card
sudo eject /dev/sda

# Or if that doesn't work:
sync
# Then physically remove the SD card
```

### Step 2: Insert SD Card into Raspberry Pi

1. **Power off** your Raspberry Pi if it's on
2. **Insert the SD card** into the Pi's SD card slot
3. **Connect ethernet cable** to the Pi (and to your network)
4. **Connect power** to the Pi

### Step 3: Wait for Boot

⏱️ **Wait about 60-90 seconds** for the Pi to boot

**What's happening:**
- Pi boots from SD card
- Network starts (DHCP on ethernet)
- SSH server starts
- mDNS advertises as `nixos.local`

**Visual check** (if you can see the Pi):
- Red LED = Power (should be solid ON)
- Green LED = Activity (should blink/flash during boot)

---

## Step 4: Find the Pi on Your Network

### Option A: Try mDNS first (easiest!)

```bash
# From your laptop
ping nixos.local
```

**If you get a response**, you can use `nixos.local` for all commands! Skip to Step 5.

### Option B: Scan your network

First, find your network's subnet:

```bash
# Show your network info
ip addr show

# Look for your ethernet or WiFi connection
# The IP will be something like 192.168.1.X or 10.0.0.X
```

Then scan for the Pi:

```bash
# Replace with your actual subnet
sudo nmap -sn 192.168.1.0/24

# For school network, might be:
sudo nmap -sn 10.0.0.0/24
# or
sudo nmap -sn 172.16.0.0/16
```

Look for entries showing:
- Hostname: "nixos" or "raspberry"
- MAC address starting with: `b8:27:eb`, `dc:a6:32`, or `e4:5f:01`

**Write down the IP address!**

### Option C: Check your router/switch

If you have access to your network's admin interface, check:
- DHCP lease table
- Connected devices list
- Look for "nixos" or the Pi's MAC address

---

## Step 5: Test SSH Connection

Before deploying, verify you can connect:

```bash
# Try with mDNS hostname
ssh root@nixos.local

# Or with IP address
ssh root@192.168.1.XXX
```

**Expected:**
- You'll get a warning about unknown host (first time) - type `yes`
- You'll be asked for a password
- **Default installer has NO root password** - it should let you in OR use the password shown on screen if you have a monitor connected

**If SSH works**, you're ready to deploy! Exit the SSH session:

```bash
exit
```

---

## Step 6: Deploy Your Configuration

This is the big moment! 🚀

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Deploy using nixos-anywhere
# Replace with your Pi's hostname or IP
just deploy-anywhere cnc-pi root@nixos.local

# Or with IP:
just deploy-anywhere cnc-pi root@192.168.1.XXX
```

### What nixos-anywhere Does:

1. **Connects** to the installer via SSH
2. **Partitions** the SD card (creates proper filesystem)
3. **Installs** NixOS with your configuration
4. **Configures**:
   - Hostname: `cnc-pi`
   - User: `vandal`
   - SSH server
   - Firewall (port 22 only)
   - Ethernet networking (DHCP)
   - All your custom settings
5. **Reboots** the Pi automatically

### Expected Time: 10-20 minutes

You'll see:
- Connection messages
- Disk partitioning output
- Package downloads
- Installation progress
- "Installation finished!" message
- Reboot

**Don't interrupt it!** Let it complete fully.

---

## Step 7: Wait for Reboot

After deployment finishes:

⏱️ **Wait 60-90 seconds** for the Pi to reboot with your new configuration

The Pi will:
- Reboot automatically
- Load your custom NixOS configuration
- Start up with hostname `cnc-pi`
- Be accessible at `cnc-pi.local`

---

## Step 8: SSH into Your Deployed System

Now connect as your user (not root):

```bash
# Try mDNS hostname
ssh vandal@cnc-pi.local

# Or with IP
ssh vandal@192.168.1.XXX
```

**Password**: Your hashed password from configuration.nix

**If you get in successfully:** 🎉 **DEPLOYMENT COMPLETE!**

---

## Step 9: Verify Everything Works

Once logged in, check the system:

```bash
# Check NixOS version and hostname
hostname
nixos-version

# Check network interfaces
ip addr show

# Should see:
# - lo (loopback)
# - eth0 (ethernet with IP address)

# Check services
systemctl status

# Check disk usage
df -h

# Check running kernel
uname -a
```

Everything should show your custom configuration!

---

## Troubleshooting

### Can't find Pi on network (Step 4)

**Wait longer**: First boot can take 2-3 minutes
- Red LED on? = Pi has power
- Green LED blinking? = Pi is active

**Check network cable**: Make sure it's plugged in at both ends

**Try direct connection**: Connect Pi directly to your laptop with ethernet cable

**School network blocking**: Some networks block:
- mDNS (port 5353)
- Device discovery
- Inter-device communication

If this is the case, you may need to:
- Use a different network
- Ask network admin for help
- Connect via a switch/hub

### SSH connection refused (Step 5)

**Wait**: SSH might still be starting (wait 30 more seconds)

**Check firewall**: Your laptop's firewall might block SSH

**Wrong IP/hostname**: Double-check the address

**Monitor connected?**: If you have a monitor, check screen for:
- Boot errors
- IP address
- SSH credentials

### nixos-anywhere fails (Step 6)

**Test SSH first**:
```bash
ssh root@nixos.local
```

If SSH doesn't work, deployment won't work either.

**Network timeout**: School network might have strict firewall rules

**Already deployed?**: If you already ran nixos-anywhere once, the installer is gone. Use regular deployment instead:
```bash
just deploy cnc-pi vandal@cnc-pi.local
```

### Can't SSH as vandal after deployment (Step 8)

**Wrong hostname**: After deployment, hostname changed from `nixos.local` to `cnc-pi.local`

**Wrong user**: Use `vandal`, not `root`

**Pi didn't reboot**: Wait a bit longer, or power cycle the Pi manually

**Check logs on the installer**: If deployment seemed to fail, SSH back as root and check:
```bash
ssh root@nixos.local
journalctl -xe
```

---

## You're Done! Next Steps

### 1. Set Up SSH Keys (Recommended)

```bash
# From your laptop
ssh-copy-id vandal@cnc-pi.local

# Test passwordless login
ssh vandal@cnc-pi.local

# Disable password auth (edit configuration.nix):
# services.openssh.settings.PasswordAuthentication = false;

# Redeploy
just deploy cnc-pi vandal@cnc-pi.local
```

### 2. Add CNC Software

Edit `modules/nixos/packages.nix` and add packages you need, then:

```bash
just deploy cnc-pi vandal@cnc-pi.local
```

### 3. Configure for Your CNC Setup

- GPIO access
- Serial ports (already configured via `dialout` group)
- USB devices
- Network settings for PLC

### 4. Test Everything

- Connect to your PLC via ethernet
- Test serial communication
- Verify all CNC tools work

---

## Quick Reference

```bash
# SSH into Pi
ssh vandal@cnc-pi.local

# Deploy config changes
just deploy cnc-pi vandal@cnc-pi.local

# Update system
just init
just deploy cnc-pi vandal@cnc-pi.local

# Check system remotely
just status
just sysinfo
just logs
```

---

## Need to Start Over?

If something goes wrong and you want to start fresh:

1. Re-flash the SD card: `just flash-sd ./result/sd-image/*.img.zst /dev/sda`
2. Boot the Pi
3. Run deployment again: `just deploy-anywhere cnc-pi root@nixos.local`

The beauty of NixOS - you can always rebuild from scratch! 🚀
