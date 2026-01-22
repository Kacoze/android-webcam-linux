#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Android Webcam Setup (Linux Universal)${NC}"
echo -e "${BLUE}=========================================${NC}"

# --- FUNCTION: DETECT PACKAGE MANAGER ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
echo -e "Detected distribution: ${BLUE}$DISTRO${NC}"

# --- STEP 1: INSTALL DEPENDENCIES ---
echo -e "\n${GREEN}[1/5] Installing system dependencies...${NC}"

install_deps() {
    case $DISTRO in
        ubuntu|debian|pop|linuxmint|kali|neon)
            echo "Using APT..."
            sudo apt update
            # Ubuntu needs 'v4l2loopback-dkms', Arch needs 'linux-headers'
            DEPS="android-tools-adb v4l2loopback-dkms v4l2loopback-utils ffmpeg libnotify-bin"
            sudo apt install -y $DEPS
            ;;
        
        arch|manjaro|endeavouros)
            echo "Using PACMAN..."
            # Arch needs headers to compile the module
            echo -e "${YELLOW}Note: Attempting to install linux-headers. If you use a custom kernel (zen/lts), install headers manually.${NC}"
            sudo pacman -Sy --needed android-tools v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg libnotify linux-headers
            ;;
            
        fedora|rhel|centos)
            echo "Using DNF..."
            sudo dnf install -y android-tools v4l2loopback v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
            
        opensuse*|suse)
            echo "Using ZYPPER..."
            sudo zypper install -y android-tools v4l2loopback-kmp-default v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
            
        *)
            echo -e "${RED}Unsupported distribution family: $DISTRO${NC}"
            echo "Please manually install: adb, v4l2loopback, scrcpy, ffmpeg"
            read -p "Press Enter if you have installed them manually..."
            ;;
    esac
}

if ! install_deps; then
    echo -e "${RED}Dependency installation failed. Please check logs.${NC}"
    exit 1
fi

# --- STEP 1.5: SCRCPY VERSION CHECK (Universal) ---
# Arch/Fedora usually have latest scrcpy. Debian/Ubuntu usually have old.

check_scrcpy_version() {
    if ! command -v scrcpy &> /dev/null; then echo "0.0"; return; fi
    scrcpy --version 2>/dev/null | head -n 1 | awk '{print $2}'
}

CURRENT_VERSION=$(check_scrcpy_version)
REQUIRED_VERSION="2.0"

echo "Checking scrcpy version... Found: $CURRENT_VERSION"

# Logic: If version is old AND we are on Ubuntu/Debian -> Force Snap.
# On Arch/Fedora we trust the repo or user intelligence.
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
    
    echo -e "${YELLOW}Version $CURRENT_VERSION is too old (Need 2.0+ for camera).${NC}"
    
    # Try Snap only if supported/installed
    if command -v snap &> /dev/null; then
        echo -e "${GREEN}Snap detected. Installing scrcpy via Snap...${NC}"
        # Remove apt version to avoid conflict
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            sudo apt remove -y scrcpy 2>/dev/null
        fi
        
        sudo snap install scrcpy
        echo "Configuring Snap permissions..."
        sudo snap connect scrcpy:camera
        sudo snap connect scrcpy:raw-usb
    else
        echo -e "${RED}CRITICAL: Your scrcpy is too old and Snap is not available.${NC}"
        echo "Please install scrcpy 2.0+ manually from GitHub (https://github.com/Genymobile/scrcpy)."
        echo "The script will try to continue, but camera might fail."
        read -p "Press Enter to continue..."
    fi
else
    echo -e "${GREEN}Scrcpy version is OK.${NC}"
fi


# --- STEP 2: KERNEL MODULE (V4L2LOOPBACK) ---
echo -e "\n${GREEN}[2/5] Configuring virtual camera driver...${NC}"

CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    echo "Writing driver configuration..."
    # Universal config path
    echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
    echo "v4l2loopback" | sudo tee "$LOAD_FILE" > /dev/null
    
    # Unload/Reload
    sudo modprobe -r v4l2loopback 2>/dev/null
    if sudo modprobe v4l2loopback; then
        echo "Module loaded successfully."
    else
        echo -e "${RED}Failed to load kernel module!${NC}"
        echo "Common fix: Restart your computer (Secure Boot might be blocking unsigned modules)."
        echo "On Arch/Fedora: Ensure kernel-headers match your kernel version."
    fi
else
    echo "Driver is already configured."
fi

# --- STEP 3: PHONE DETECTION ---
echo -e "\n${GREEN}[3/5] Pairing phone...${NC}"
echo "---------------------------------------------------"
echo "1. Connect phone via USB."
echo "2. Enable USB Debugging."
echo "3. Accept RSA key on phone."
echo "---------------------------------------------------"
echo "Waiting for device..."

adb wait-for-usb-device
PHONE_IP=$(adb shell ip -4 -o addr show wlan0 | awk '{print $4}' | cut -d/ -f1)

if [ -z "$PHONE_IP" ]; then
    echo -e "${YELLOW}Could not detect IP automatically.${NC}"
    read -p "Enter phone IP manually: " PHONE_IP
else
    echo -e "Found IP: ${BLUE}$PHONE_IP${NC}"
fi

# Config
CONFIG_DIR="$HOME/.config/android-webcam"
mkdir -p "$CONFIG_DIR"
echo "PHONE_IP=$PHONE_IP:5555" > "$CONFIG_DIR/config.env"

adb tcpip 5555
sleep 2

# --- STEP 4: SCRIPTS ---
echo -e "\n${GREEN}[4/5] Creating scripts...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# -- TOGGLE SCRIPT --
cat << 'EOF' > "$BIN_DIR/android-cam-toggle.sh"
#!/bin/bash
source ~/.config/android-webcam/config.env
LOG="/tmp/android-cam.log"

if pgrep -f "scrcpy.*video-source=camera" > /dev/null; then
    pkill -f "scrcpy.*video-source=camera"
    notify-send -u low -i camera-web "Android Camera" "Stopped."
    exit 0
fi

notify-send -u low -i camera-web "Android Camera" "Starting..."

# Try to connect (just in case)
adb connect $PHONE_IP > /dev/null

# Start scrcpy
# Note: Snap path might differ, so we use $(command -v scrcpy)
SCRCPY_BIN=$(command -v scrcpy)
nohup $SCRCPY_BIN -s $PHONE_IP --video-source=camera --camera-facing=front --v4l2-sink=/dev/video0 --no-audio > "$LOG" 2>&1 &
PID=$!

sleep 3
if ps -p $PID > /dev/null; then
    notify-send -u normal -i camera-web "Android Camera" "Active (PID: $PID)"
else
    notify-send -u critical -i error "Camera Error" "Check logs in $LOG"
fi
EOF

# -- FIX SCRIPT --
cat << 'EOF' > "$BIN_DIR/android-cam-fix.sh"
#!/bin/bash
notify-send -i smartphone "Camera Setup" "Connect USB..."
adb wait-for-usb-device
adb tcpip 5555
notify-send -i smartphone "Camera Setup" "Done! Disconnect USB."
EOF

chmod +x "$BIN_DIR/android-cam-toggle.sh"
chmod +x "$BIN_DIR/android-cam-fix.sh"

# --- STEP 5: ICONS ---
echo -e "\n${GREEN}[5/5] Creating icons...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

cat << EOF > "$APP_DIR/android-cam.desktop"
[Desktop Entry]
Version=1.0
Name=Camera Phone
Comment=Toggle Android Camera
Exec=$BIN_DIR/android-cam-toggle.sh
Icon=camera-web
Terminal=false
Type=Application
Categories=Utility;Video;
EOF

cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Fix Camera (USB)
Comment=Reconnect after restart
Exec=$BIN_DIR/android-cam-fix.sh
Icon=smartphone
Terminal=false
Type=Application
Categories=Utility;Settings;
EOF

update-desktop-database "$APP_DIR" 2>/dev/null

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE!                ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "Works on: $DISTRO"
echo "You can unplug the USB now."