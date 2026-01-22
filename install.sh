#!/bin/bash

# =============================================================================
# 📸 Android Webcam Setup for Linux (Universal)
# =============================================================================
# Transforms your Android device into a low-latency HD webcam for Linux.
# GitHub: https://github.com/TWOJ_NICK/android-webcam-linux
# =============================================================================

# --- CONSTANTS & COLORS ---
readonly VERSION="2.1.0"
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# --- HELPER FUNCTIONS ---

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}   Android Webcam Setup v${VERSION}  ${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

check_internet() {
    log_info "Checking internet connection..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected."
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

check_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log_warn "Your ~/.local/bin is NOT in your \$PATH."
        echo "The script will install correctly, but commands might not run globally."
        echo "Recommend adding this to ~/.bashrc or ~/.zshrc:"
        echo -e "${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo "Continuing in 3 seconds..."
        sleep 3
    fi
}

uninstall() {
    echo -e "${RED}!!! WARNING !!!${NC}"
    echo "This will remove configuration files, icons, and control scripts."
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    
    log_info "Removing files..."
    rm -rf "$HOME/.local/bin/android-cam-toggle.sh"
    rm -rf "$HOME/.local/bin/android-cam-fix.sh"
    rm -rf "$HOME/.config/android-webcam"
    rm -rf "$HOME/.local/share/applications/android-cam.desktop"
    rm -rf "$HOME/.local/share/applications/android-cam-fix.desktop"
    
    echo "Do you want to remove system dependencies (scrcpy, v4l2loopback etc.)?"
    echo "Only say YES if you don't use them for other things."
    read -p "Remove packages? (y/N): " pkg_confirm
    if [[ "$pkg_confirm" == "y" || "$pkg_confirm" == "Y" ]]; then
        DISTRO=$(detect_distro)
        case $DISTRO in
            ubuntu|debian|pop|linuxmint|zorin) sudo apt remove -y scrcpy v4l2loopback-dkms v4l2loopback-utils android-tools-adb ;;
            arch|manjaro) sudo pacman -Rs scrcpy v4l2loopback-dkms android-tools ;;
            fedora) sudo dnf remove -y scrcpy v4l2loopback ;;
            *) echo "Please remove packages manually for your distro." ;;
        esac
    fi
    
    log_success "Uninstallation completed."
    exit 0
}

# --- ARGUMENT PARSING ---
case "$1" in
    --uninstall|-u) uninstall ;;
    --help|-h) 
        print_banner
        echo "Usage: ./install.sh [OPTIONS]"
        echo "Options:"
        echo "  --uninstall, -u   Remove the tool and cleanup"
        echo "  --help, -h        Show this help"
        exit 0
        ;;
esac

# =============================================================================
# MAIN INSTALLATION LOGIC
# =============================================================================

print_banner
check_internet
check_path

DISTRO=$(detect_distro)
echo -e "Detected System: ${BLUE}${DISTRO^}${NC}"

# --- STEP 1: DEPENDENCIES ---
echo -e "\n${GREEN}[1/5] Installing System Dependencies...${NC}"

install_deps() {
    case $DISTRO in
        ubuntu|debian|pop|linuxmint|kali|neon|zorin)
            log_info "Using APT..."
            sudo apt update
            DEPS="android-tools-adb v4l2loopback-dkms v4l2loopback-utils ffmpeg libnotify-bin"
            sudo apt install -y $DEPS
            ;;
        arch|manjaro|endeavouros|garuda)
            log_info "Using PACMAN..."
            log_warn "Arch users: Ensure you have headers installed (linux-headers / linux-zen-headers) matching your kernel!"
            sudo pacman -Sy --needed android-tools v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
        fedora|rhel|centos|nobara)
            log_info "Using DNF..."
            # Check for RPMFusion (needed for v4l2loopback)
            if ! dnf repolist | grep -q "rpmfusion"; then
                log_warn "Fedora requires RPMFusion for v4l2loopback."
                echo "Please enable RPMFusion Free and Non-Free repositories."
                read -p "Press Enter to try installing anyway (might fail)..."
            fi
            sudo dnf install -y android-tools v4l2loopback v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
        opensuse*|suse)
            log_info "Using ZYPPER..."
            sudo zypper install -y android-tools v4l2loopback-kmp-default v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            echo "Manual install required: adb, v4l2loopback, scrcpy, ffmpeg, libnotify"
            read -p "Press Enter if you have installed them manually..."
            ;;
    esac
}

if ! install_deps; then
    log_error "Dependency installation failed."
    exit 1
fi

# --- STEP 1.5: SCRCPY VERSION CHECK ---
echo -e "\n${GREEN}[Check] Verifying scrcpy version...${NC}"

check_scrcpy() {
    if ! command -v scrcpy &> /dev/null; then echo "0.0"; return; fi
    scrcpy --version 2>/dev/null | head -n 1 | awk '{print $2}'
}

CURRENT_VER=$(check_scrcpy)
REQUIRED_VER="2.0"

# Compare version logic
if [ "$(printf '%s\n' "$REQUIRED_VER" "$CURRENT_VER" | sort -V | head -n1)" = "$CURRENT_VER" ] && [ "$CURRENT_VER" != "$REQUIRED_VER" ]; then
    log_warn "Scrcpy v$CURRENT_VER is too old (Need v$REQUIRED_VER+)."
    
    if command -v snap &> /dev/null; then
        log_info "Attempting upgrade via Snap..."
        # Clean up apt version to prevent conflicts
        [[ "$DISTRO" =~ (ubuntu|debian|mint|pop|zorin) ]] && sudo apt remove -y scrcpy 2>/dev/null
        
        sudo snap install scrcpy
        sudo snap connect scrcpy:camera
        sudo snap connect scrcpy:raw-usb
        log_success "Scrcpy installed via Snap."
    else
        log_error "Manual update required. Install scrcpy 2.0+ from GitHub."
        read -p "Press Enter to continue at your own risk (Camera might not work)..."
    fi
else
    log_success "Scrcpy v$CURRENT_VER is compatible."
fi

# --- STEP 2: KERNEL MODULE ---
echo -e "\n${GREEN}[2/5] Configuring V4L2 Module...${NC}"

CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    log_info "Creating module configuration..."
    echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
    echo "v4l2loopback" | sudo tee "$LOAD_FILE" > /dev/null
    
    log_info "Reloading module..."
    sudo modprobe -r v4l2loopback 2>/dev/null
    if sudo modprobe v4l2loopback; then
        log_success "Module loaded."
    else
        log_error "Failed to load module."
        echo -e "${YELLOW}Possible cause: Secure Boot is enabled.${NC}"
        echo "If so, you need to sign the module or disable Secure Boot in BIOS."
        echo "Or simply REBOOT your computer and try again."
    fi
else
    log_success "Module check passed."
fi

# --- STEP 3: PHONE PAIRING ---
echo -e "\n${GREEN}[3/5] Pairing Phone...${NC}"
echo "---------------------------------------------------"
echo " 1. USB Connection: YES (Connect cable now)"
echo " 2. USB Debugging:  ENABLED (In Developer Options)"
echo " 3. RSA Prompt:     ACCEPTED (On phone screen)"
echo "---------------------------------------------------"
log_info "Waiting for device (Ctrl+C to cancel)..."

adb wait-for-usb-device

log_success "Device connected!"
log_info "Detecting Wi-Fi IP address..."

# Smart Loop for Interface Detection
PHONE_IP=""
for iface in wlan0 swlan0 wlan1 wlan2 eth0; do
    IP=$(adb shell ip -4 -o addr show $iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ ! -z "$IP" ]; then
        PHONE_IP=$IP
        log_success "Found IP ($iface): $PHONE_IP"
        break
    fi
done

if [ -z "$PHONE_IP" ]; then
    log_warn "Could not auto-detect Wi-Fi IP."
    echo "Make sure the phone is connected to the same Wi-Fi network."
    read -p "Enter phone IP manually (e.g., 192.168.1.50): " PHONE_IP
fi

# Save config
CONFIG_DIR="$HOME/.config/android-webcam"
mkdir -p "$CONFIG_DIR"
echo "PHONE_IP=$PHONE_IP:5555" > "$CONFIG_DIR/config.env"

log_info "Enabling TCP/IP mode..."
adb tcpip 5555
sleep 3

# --- STEP 4: SCRIPTS ---
echo -e "\n${GREEN}[4/5] Generating Control Scripts...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# -- TOGGLE SCRIPT --
cat << 'EOF' > "$BIN_DIR/android-cam-toggle.sh"
#!/bin/bash
source ~/.config/android-webcam/config.env
LOG="/tmp/android-cam.log"

# Check if running
if pgrep -f "scrcpy.*video-source=camera" > /dev/null; then
    pkill -f "scrcpy.*video-source=camera"
    notify-send -u low -i camera-web "Android Camera" "⏹ Stopped"
    exit 0
fi

notify-send -u low -i camera-web "Android Camera" "⌛ Connecting..."

# Try silent reconnect
adb connect $PHONE_IP > /dev/null

# Determine binary path
SCRCPY_BIN=$(command -v scrcpy)
if [ -z "$SCRCPY_BIN" ] && [ -f /snap/bin/scrcpy ]; then
    SCRCPY_BIN="/snap/bin/scrcpy"
fi

# Launch
nohup $SCRCPY_BIN -s $PHONE_IP --video-source=camera --camera-facing=front --v4l2-sink=/dev/video0 --no-audio > "$LOG" 2>&1 &
PID=$!

sleep 3
if ps -p $PID > /dev/null; then
    notify-send -u normal -i camera-web "Android Camera" "✅ Active (PID: $PID)"
else
    ERR=$(head -n 2 "$LOG")
    notify-send -u critical -i error "Camera Error" "Failed to start"
fi
EOF

# -- FIX SCRIPT --
cat << 'EOF' > "$BIN_DIR/android-cam-fix.sh"
#!/bin/bash
notify-send -i smartphone "Camera Setup" "🔌 Connect USB Cable..."
adb wait-for-usb-device
adb tcpip 5555
notify-send -i smartphone "Camera Setup" "✅ Fixed! Unplug USB."
EOF

chmod +x "$BIN_DIR/android-cam-toggle.sh"
chmod +x "$BIN_DIR/android-cam-fix.sh"

# --- STEP 5: ICONS ---
echo -e "\n${GREEN}[5/5] Creating Launcher Icons...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

# Main Icon with Right-Click Action
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
Actions=Fix;

[Desktop Action Fix]
Name=Fix Connection (USB)
Exec=$BIN_DIR/android-cam-fix.sh
EOF

# Separate Fix Icon (Optional but kept for compatibility)
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
echo -e "${GREEN}   ✨ INSTALLATION COMPLETE! ✨          ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "1. Unplug USB Cable."
echo "2. Use 'Camera Phone' icon to toggle webcam."
echo "3. If it fails, use 'Fix Camera (USB)'."
echo ""
echo -e "To uninstall, run: ${YELLOW}./install.sh --uninstall${NC}"