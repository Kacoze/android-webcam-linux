# 📸 Android Webcam for Linux (Wireless)

Turn your Android phone into a professional HD webcam for Linux.
**No dedicated apps required on the phone.** This solution relies on system ADB and the `scrcpy` engine.

![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square)
![OS](https://img.shields.io/badge/OS-Linux%20(Universal)-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

## ✨ Why this solution?

Most solutions (DroidCam, Iriun) require installing "bloatware" on both phone and computer, often containing ads or resolution limits. This project offers:

*   🚀 **Zero apps on phone** (uses built-in USB debugging).
*   ⚡ **Ultra low latency** (via P2P protocol and `scrcpy`).
*   🎥 **High Quality** (HD/Full HD depending on phone).
*   🐧 **Native Integration** (visible as `/dev/video10` in Zoom, Teams, OBS, Chrome).
*   🔋 **Battery Saving** (phone screen typically turns off during operation to save battery).

---

## ⚙️ Requirements

1.  **System:** Linux (tested on Ubuntu 22.04 / 24.04, Debian, Mint, Pop!_OS, Arch Linux, Manjaro, Fedora, openSUSE, and others).
2.  **Phone:** Android 5.0 or newer.
3.  **Network:** After initial USB pairing, computer and phone must be on the same Wi-Fi network for wireless operation. USB connection is only required for the initial setup and re-pairing after phone restart.
4.  **Software:** `scrcpy` version 2.0 or newer (installer attempts to handle this automatically).
5.  **Privileges:** ⚠️ **Administrator access (sudo) is required** for installing system packages and kernel modules. The installer will prompt for your password.
6.  **Permissions:** Your user should be in the `video` group to access `/dev/video*` devices. This is usually automatic on most distributions, but you can verify with `groups | grep video`. If not present, add yourself with `sudo usermod -aG video $USER` and log out/in.
7.  **Internet:** ⚠️ **Active internet connection is required ONLY during installation** for:
    - Downloading system dependencies (via package manager)
    - Downloading `scrcpy` from GitHub Releases (if not available via package manager, Snap, or Flatpak)
    
    **Note:** After installation, the tool works completely offline. No internet connection is needed for daily use.

### Hardware Requirements

- **Kernel:** Linux kernel 3.6 or newer (for v4l2loopback support)
- **Secure Boot:** If enabled, you may need to disable it or sign the v4l2loopback module (see FAQ section)
- **USB:** USB cable for initial pairing (any standard USB cable works)

### 📱 Step 0: Phone Preparation (One-time only)

Before running the installer, you must enable **USB Debugging** on your phone:

1.  Go to `Settings` -> `About phone`.
2.  Tap **Build number** 7 times (until "You are now a developer" appears).
3.  Go back to main menu -> `System` (or Additional settings) -> `Developer options`.
4.  Enable **USB Debugging**.

---


## 📥 Installation (One-Liner)

**⚠️ Before proceeding:**
- Make sure you have **administrator (sudo) privileges** - the installer will prompt for your password
- Ensure you have an **active internet connection** (required only during installation)
- The installer will ask you to connect your phone via USB cable once to automatically detect its IP address and pair the devices

Open a terminal (Ctrl+Alt+T) and paste one of the following commands:

**Using wget:**
```bash
wget -O - https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh | bash
```

**Or using curl (if wget is not available):**
```bash
curl -fsSL https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh | bash
```

> **Note:** The installer will ask you to connect your phone via USB cable once to automatically detect its IP address and pair the devices.

The control script `android-webcam-ctl` is installed to `/usr/local/bin`, so it is available in the terminal and from the application menu without adding any directory to your PATH.

---

## 🚀 How to use?

After installation, you will find two new entries in your application menu (Super/Windows key): **Camera Phone** (toggle webcam) and **Fix Camera (USB)** (reconnect after restart). If the icons do not appear immediately, log out and log back in so your desktop refreshes the application list.

### 1. Daily Usage (Wireless)

When you want to join a call:

1.  Ensure your phone has Wi-Fi enabled.
2.  Click the **📷 Camera Phone** icon in the app menu.

**What happens?**

*   A system notification appears: "Android Camera: Active".
*   The phone screen typically turns off automatically (to save battery).
*   Open Zoom/Teams/Discord and select the camera: **Android Cam** (appears as `/dev/video10`).

**To turn off:** Simply click the **📷 Camera Phone** icon again or use the notification action.

### 2. Application Examples

The camera appears as **Android Cam** (device `/dev/video10`) in applications:

**OBS Studio:**
1. Open OBS Studio
2. Add Source → Video Capture Device
3. Select "Android Cam" or "/dev/video10"

**Zoom / Microsoft Teams:**
1. Open video settings
2. Select camera: "Android Cam" or "/dev/video10"

**Discord:**
1. User Settings → Voice & Video
2. Camera: Select "Android Cam"

**Chrome/Chromium (for web apps):**
The camera should appear automatically as "Android Cam" in browser permission dialogs.

### 3. Advanced Controls (Right-Click)

Right-click the **Camera Phone** icon to access:
- **Settings**: Opening the configuration file allows you to change back/front camera, resolution, etc.
- **Check Status**: See if the camera is running and check current settings.
- **Fix Connection**: Quick access to USB re-pairing tool.

### 4. Emergency Situation (After Phone Restart)

If you restarted your phone or the battery died, Android disables wireless debugging access for security reasons.

1.  Click the **🔧 Fix Camera (USB)** icon (or use Right-Click -> Fix).
2.  A message will appear: "Connect phone via USB cable...".
3.  Connect your phone to the computer for about 3 seconds.
4.  When you see "Done! You can disconnect the cable", disconnect it.

---

## ⚙️ Configuration

You can customize the camera settings by editing the config file (`right-click icon -> Settings`) or running:

```bash
android-webcam-ctl config
```

File location: `~/.config/android-webcam/settings.conf`

```bash
PHONE_IP="192.168.1.50"   # Your phone's Wi-Fi IP address
CAMERA_FACING="back"      # Options: front, back, external
VIDEO_SIZE=""             # Max dimension in pixels (e.g., "1080" for 1080p), leave empty for max resolution
BIT_RATE="8M"             # Higher = better quality, more latency
EXTRA_ARGS="--no-audio --v4l2-buffer=400"  # Additional scrcpy arguments
```

### Example Configurations

**High Quality (1080p, 12Mbps):**
```bash
PHONE_IP="192.168.1.50"
CAMERA_FACING="back"
VIDEO_SIZE="1080"
BIT_RATE="12M"
EXTRA_ARGS="--no-audio --v4l2-buffer=400"
```

**Low Latency (720p, 4Mbps):**
```bash
PHONE_IP="192.168.1.50"
CAMERA_FACING="back"
VIDEO_SIZE="720"
BIT_RATE="4M"
EXTRA_ARGS="--no-audio --v4l2-buffer=200"
```

**Front Camera (Selfie Mode):**
```bash
PHONE_IP="192.168.1.50"
CAMERA_FACING="front"
VIDEO_SIZE="1080"
BIT_RATE="8M"
EXTRA_ARGS="--no-audio --v4l2-buffer=400"
```

**Maximum Quality (No Resolution Limit):**
```bash
PHONE_IP="192.168.1.50"
CAMERA_FACING="back"
VIDEO_SIZE=""              # Empty = maximum supported resolution
BIT_RATE="16M"             # High bitrate for best quality
EXTRA_ARGS="--no-audio --v4l2-buffer=400"
```

**Note:** After changing configuration, restart the camera (stop and start) for changes to take effect.

---

## ❓ FAQ (Frequently Asked Questions)

**Why is the phone screen black?**
This is intentional. The camera runs in the background and streams video directly to the computer. This prevents the phone from overheating and saves battery.

**Image is rotated / Mirrored?**
Most messengers (Zoom/Teams) mirror your video by default (you see yourself reversed), but others see you correctly. You don't need to fix this.

**Quality is poor / lagging?**
Make sure your phone and computer are on the same Wi-Fi network (preferably 5GHz). Weak signal can cause stuttering.

**Camera not visible in Zoom/Teams (/dev/video10 missing)?**
The v4l2loopback kernel module may not be loaded. Check with:
```bash
lsmod | grep v4l2loopback
```
If empty, try loading it manually:
```bash
sudo modprobe v4l2loopback
```
If this fails, you may have Secure Boot enabled. Either disable Secure Boot in BIOS or sign the kernel module.

**I changed my router / network, what to do?**
If the phone's IP address changed, you can either:

1. Run the installer again to auto-detect the new IP.
2. Edit the config file manually:
   ```bash
   nano ~/.config/android-webcam/settings.conf
   ```
   and update the line:
   ```bash
   PHONE_IP="192.168.1.50"  # Replace with your new phone IP
   ```
3. Or use the config command:
   ```bash
   android-webcam-ctl config
   ```

**What to do when Secure Boot blocks the v4l2loopback module?**
If `sudo modprobe v4l2loopback` fails with a "Required key not available" error, Secure Boot is enabled. You have two options:

1. **Disable Secure Boot** (easier, but less secure):
   - Restart your computer and enter BIOS/UEFI settings (usually F2, F10, F12, or Del during boot)
   - Find "Secure Boot" option and disable it
   - Save and exit, then try `sudo modprobe v4l2loopback` again

2. **Sign the kernel module** (more secure, but complex):
   - This requires generating a Machine Owner Key (MOK) and signing the module
   - Detailed instructions vary by distribution - search for "sign kernel module secure boot" for your distro

**How to check scrcpy version?**
Run one of these commands:
```bash
# If installed via package manager:
scrcpy --version

# If installed via Snap:
/snap/bin/scrcpy --version

# If installed via Flatpak:
flatpak run org.scrcpy.ScrCpy --version

# If installed manually:
~/.local/bin/scrcpy --version
```
The installer requires scrcpy version 2.0 or newer.

**What if the phone doesn't connect via Wi-Fi?**
Troubleshooting steps:

1. **Check if phone and computer are on the same Wi-Fi network** - they must be on the same network for wireless connection to work.

2. **Verify USB debugging is still enabled** - sometimes Android disables it after restart.

3. **Re-run the pairing process** - use the "Fix Camera (USB)" icon or run:
   ```bash
   android-webcam-ctl fix
   ```
   Then connect via USB cable and follow the prompts.

4. **Check phone's IP address** - the IP might have changed. Run:
   ```bash
   android-webcam-ctl status
   ```
   to see the current configuration, or edit the config file manually.

5. **Test ADB connection manually**:
   ```bash
   adb connect YOUR_PHONE_IP:5555
   ```
   Replace `YOUR_PHONE_IP` with your phone's actual IP address.

**Is internet required after installation?**
No. Internet is only required **during installation** for:
- Downloading system dependencies via package manager
- Downloading scrcpy from GitHub (if not available via package manager, Snap, or Flatpak)

After installation, the tool works completely offline. It only needs:
- Your phone and computer on the same Wi-Fi network (for wireless connection)
- Or USB cable connection (for initial pairing)

---

## 🔧 Troubleshooting

### Common Issues

#### "v4l2loopback module not found" or "/dev/video10 missing"

**Symptoms:** Camera not visible in Zoom/Teams/OBS, or error message about missing video device.

**Solutions:**
1. Check if module is loaded:
   ```bash
   lsmod | grep v4l2loopback
   ```
2. If empty, try loading manually:
   ```bash
   sudo modprobe v4l2loopback
   ```
3. If this fails with "Required key not available", Secure Boot is enabled. See FAQ section for Secure Boot solutions.

#### "scrcpy: command not found" or "scrcpy version too old"

**Symptoms:** Camera fails to start, error about scrcpy not being found or version being too old.

**Solutions:**
1. Check scrcpy version (see FAQ section for commands)
2. Install/update scrcpy:
   - Snap: `sudo snap install scrcpy`
   - Flatpak: `flatpak install flathub org.scrcpy.ScrCpy`
   - Or download from: https://github.com/Genymobile/scrcpy/releases
3. Re-run the installer to auto-detect the new installation

#### "Connection refused" when starting camera

**Symptoms:** Camera fails to start, error about connection being refused.

**Solutions:**
1. **Check if phone and computer are on the same Wi-Fi network** - they must be on the same network for wireless connection to work.
2. **Verify phone's IP address** - the IP might have changed. Run:
   ```bash
   android-webcam-ctl status
   ```
   to see the current configuration.
3. **Re-run the pairing process** - use the "Fix Camera (USB)" icon or run:
   ```bash
   android-webcam-ctl fix
   ```
   Then connect via USB cable and follow the prompts.
4. **Test ADB connection manually**:
   ```bash
   adb connect YOUR_PHONE_IP:5555
   ```
   Replace `YOUR_PHONE_IP` with your phone's actual IP address.

#### "Required key not available" (Secure Boot)

**Symptoms:** `sudo modprobe v4l2loopback` fails with Secure Boot error.

**Solutions:**
See FAQ section "What to do when Secure Boot blocks the v4l2loopback module?" for detailed instructions.

#### Camera shows black screen or no video

**Symptoms:** Camera appears in applications but shows black screen or no video.

**Solutions:**
1. Check if camera is actually running:
   ```bash
   android-webcam-ctl status
   ```
2. Check phone's camera permissions - ensure camera app works on phone
3. Try restarting the camera:
   ```bash
   android-webcam-ctl stop
   android-webcam-ctl start
   ```
4. Check logs: `/tmp/android-cam.log`

#### Poor quality or lagging video

**Symptoms:** Video quality is poor or stuttering.

**Solutions:**
1. Ensure phone and computer are on the same Wi-Fi network (preferably 5GHz)
2. Check Wi-Fi signal strength - weak signal can cause stuttering
3. Try increasing bitrate in config (higher = better quality, more latency):
   ```bash
   android-webcam-ctl config
   # Edit BIT_RATE="8M" to higher value like "12M" or "16M"
   ```

---

## 🗑️ Uninstall

If you want to remove the tool:

**If you have the installer locally:**
```bash
./install.sh --uninstall
```

**If you installed via one-liner (`wget ... | bash` or `curl ... | bash`):**
```bash
# Using wget:
wget -O /tmp/install.sh https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh
bash /tmp/install.sh --uninstall

# Or using curl:
curl -fsSL https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh -o /tmp/install.sh
bash /tmp/install.sh --uninstall
```

**Alternatively, you can manually delete the files:**

```bash
# Remove script (installed to /usr/local/bin), config, and icons
sudo rm -f /usr/local/bin/android-webcam-ctl
rm -f ~/.local/bin/android-webcam-ctl   # legacy location, if any
rm -rf ~/.config/android-webcam
rm -f ~/.local/share/applications/android-cam.desktop
rm -f ~/.local/share/applications/android-cam-fix.desktop

# Optional: remove system dependencies
# Ubuntu/Debian/Mint:
sudo apt remove -y scrcpy v4l2loopback-dkms v4l2loopback-utils

# Arch/Manjaro:
sudo pacman -Rs scrcpy v4l2loopback-dkms

# Fedora:
sudo dnf remove -y scrcpy v4l2loopback v4l2loopback-utils

# openSUSE:
sudo zypper remove -y scrcpy v4l2loopback-kmp-default v4l2loopback-utils
```

## 🤝 Credits

This project is a wrapper using brilliant Open Source tools:

*   [scrcpy](https://github.com/Genymobile/scrcpy) (Genymobile)
*   [v4l2loopback](https://github.com/umlaeute/v4l2loopback)