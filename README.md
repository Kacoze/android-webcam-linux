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
3.  **Network:** Computer and phone must be on the same Wi-Fi network.
4.  **Software:** `scrcpy` version 2.0 or newer (installer attempts to handle this).
5.  **Privileges:** Administrator access (sudo) required for installing system packages and kernel modules.
6.  **Internet:** Active internet connection is **required during installation** for:
    - Downloading system dependencies (via package manager)
    - Downloading `scrcpy` from GitHub Releases (if not available via package manager, Snap, or Flatpak)

### 📱 Step 0: Phone Preparation (One-time only)

Before running the installer, you must enable **USB Debugging** on your phone:

1.  Go to `Settings` -> `About phone`.
2.  Tap **Build number** 7 times (until "You are now a developer" appears).
3.  Go back to main menu -> `System` (or Additional settings) -> `Developer options`.
4.  Enable **USB Debugging**.

---

## 📥 Installation (One-Liner)

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

---

## 🚀 How to use?

After installation, you will find two new icons in your application menu (Super/Windows key).

### 1. Daily Usage (Wireless)

When you want to join a call:

1.  Ensure your phone has Wi-Fi enabled.
2.  Click the **📷 Camera Phone** icon in the app menu.

**What happens?**

*   A system notification appears: "Android Camera: Active".
*   The phone screen typically turns off automatically (to save battery).
*   Open Zoom/Teams/Discord and select the camera: **Android Cam** (appears as `/dev/video10`).

**To turn off:** Simply click the **📷 Camera Phone** icon again or use the notification action.

### 2. Advanced Controls (Right-Click)

Right-click the **Camera Phone** icon to access:
- **Settings**: Opening the configuration file allows you to change back/front camera, resolution, etc.
- **Check Status**: See if the camera is running and check current settings.
- **Fix Connection**: Quick access to USB re-pairing tool.

### 3. Emergency Situation (After Phone Restart)

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
EXTRA_ARGS="--no-audio --buffer=400"  # Additional scrcpy arguments
```

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
# Remove scripts, config, and icons
rm -f ~/.local/bin/android-webcam-ctl
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