# Deployment to NILE ROBOT Network

This guide shows how to deploy NixOS to your Raspberry Pi 4 using the nvmd approach with WiFi auto-connection to the "NILE ROBOT" network.

## Prerequisites

- 2x Samsung 128GB SD cards (you have these!)
- Raspberry Pi 4 Model B
- Your work/school computer with Nix installed
- Access to "NILE ROBOT" WiFi network

## Step-by-Step Deployment (The nvmd Way)

### Step 1: Download Pre-built Installer Image

No building required! Download the official nvmd installer from their binary cache:

```bash
cd ~/Projects/flakes/cnc-pi-flake
just download-installer
```

This downloads a pre-built, tested image with:
- Working network tools (mDNS, iwd for WiFi)
- SSH enabled
- Ready to receive nixos-anywhere deployment

### Step 2: Flash to SD Card

**IMPORTANT**: Identify your SD card device first!

```bash
# List available storage devices
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|NAME"
```

Look for your 128GB Samsung card (will show as ~119GB due to formatting).

Then flash:

```bash
# Replace /dev/sdX with your actual device (e.g., /dev/sdb)
just flash-sd ./result/sd-image/*.img /dev/sdX
```

The script will ask for confirmation before writing.

### Step 3: Boot the Pi with Installer

1. Insert the SD card into your Raspberry Pi 4
2. Connect power
3. Wait ~30-60 seconds for boot

**Monitor the screen** (if connected) - it will show:
- Network connection status
- IP address
- SSH credentials (randomly generated)

### Step 4: Connect to Installer via WiFi

The installer uses `iwd` for WiFi. You need to configure it to connect to "NILE ROBOT":

#### Option A: Connect via Ethernet First (Easier)

If you can plug in ethernet temporarily:

```bash
# Find the Pi on network (look for raspberry pi MAC addresses)
sudo nmap -sn <your-subnet>

# SSH in (use credentials shown on screen, or try default)
ssh root@<pi-ip>
```

#### Option B: Connect Monitor/Keyboard

If you have a monitor and keyboard handy, connect them and configure WiFi directly on the Pi.

### Step 5: Configure WiFi on Installer (Using iwd)

Once you're SSH'd into the installer or at the console:

```bash
# Start iwd interactive mode
iwctl

# Inside iwctl:
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NILE ROBOT"
# When prompted, enter password: 12345678
exit

# Verify connection
ping 8.8.8.8
```

The Pi should now be on the "NILE ROBOT" network and auto-approved!

### Step 6: Deploy Your Configuration with nixos-anywhere

From your work/school computer:

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Find the Pi's IP on NILE ROBOT network
# (check your screen or use nmap)

# Deploy your configuration
# This will:
# - Partition the SD card
# - Install NixOS with YOUR config (including WiFi auto-connect)
# - Replace the installer completely
just deploy-anywhere cnc-pi root@<pi-ip-on-nile>
```

This will take 5-15 minutes. It's doing everything automatically:
- Partitioning storage
- Installing NixOS
- Configuring WiFi for "NILE ROBOT" (so it auto-connects on every boot!)
- Setting up your user, SSH, firewall, etc.

### Step 7: Reboot and Verify

After deployment completes:

```bash
# The Pi will reboot automatically
# Wait ~30 seconds, then SSH in as your user:
ssh vandal@cnc-pi.local

# Or by IP:
ssh vandal@<pi-ip>
```

Your Pi is now running YOUR configuration and will auto-connect to "NILE ROBOT" on every boot!

## What Just Happened?

1. **Installer Image**: Pre-built by nvmd, uses `iwd` for WiFi - just a temporary installation media
2. **Your Config**: Uses NetworkManager with pre-configured "NILE ROBOT" credentials
3. **nixos-anywhere**: Automatically deployed your config, completely replacing the installer

The installer is gone - your Pi is now running your permanent NixOS configuration!

## Troubleshooting

### Can't find Pi on network after installer boot

- Check both LEDs are on (red=power, green=activity)
- Try scanning network: `sudo nmap -sn <subnet>`
- Try pinging: `ping cnc-pi.local`
- Connect monitor to see IP address on screen

### WiFi not auto-connecting after deployment

The configuration includes WiFi auto-connect settings. If it's not working:

```bash
# SSH in via ethernet or console
ssh vandal@cnc-pi.local

# Check NetworkManager status
nmcli device status
nmcli connection show

# Manually connect if needed
nmcli device wifi connect "NILE ROBOT" password 12345678
```

### Want to update configuration later

```bash
cd ~/Projects/flakes/cnc-pi-flake

# Make your changes to configuration.nix
# Then deploy:
just deploy cnc-pi vandal@cnc-pi.local
```

## Security Notes

- Password authentication is currently enabled for SSH (for ease of initial setup)
- After you verify everything works, you should:
  1. Set up SSH key authentication: `just ssh-copy-id`
  2. Disable password auth in `configuration.nix`
  3. Redeploy with `just deploy cnc-pi vandal@cnc-pi.local`

## Next Steps

- Set up SSH keys for passwordless access
- Add CNC-specific software packages
- Configure GPIO/serial/USB device access as needed
- Consider adding more security hardening
