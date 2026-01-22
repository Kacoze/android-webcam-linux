#!/bin/bash

# =============================================================================
# 📸 Android Webcam Setup for Linux (Universal)
# =============================================================================
# Transforms your Android device into a low-latency HD webcam for Linux.
# GitHub: https://github.com/TWOJ_NICK/android-webcam-linux
# =============================================================================

# --- CONSTANTS & COLORS ---
readonly VERSION="2.2.0"
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
        echo -e "Required for execution. Please add this to your shell config:"
        echo -e "${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        sleep 2
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
    rm -f "$HOME/.local/bin/android-webcam-ctl"
    rm -f "$HOME/.local/bin/android-cam-toggle.sh" # cleanup legacy
    rm -f "$HOME/.local/bin/android-cam-fix.sh"    # cleanup legacy
    rm -rf "$HOME/.config/android-webcam"
    rm -f "$HOME/.local/share/applications/android-cam.desktop"
    rm -f "$HOME/.local/share/applications/android-cam-fix.desktop"
    
    log_success "Files removed."
    
    echo "Do you want to remove system dependencies (scrcpy, v4l2loopback etc.)?"
    read -p "Remove packages? (y/N): " pkg_confirm
    if [[ "$pkg_confirm" == "y" || "$pkg_confirm" == "Y" ]]; then
        DISTRO=$(detect_distro)
        case $DISTRO in
            ubuntu|debian|pop|linuxmint|zorin|kali|neon) sudo apt remove -y scrcpy v4l2loopback-dkms v4l2loopback-utils android-tools-adb ;;
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
            sudo pacman -Sy --needed android-tools v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg libnotify
            ;;
        fedora|rhel|centos|nobara)
            log_info "Using DNF..."
            if ! dnf repolist | grep -q "rpmfusion"; then
                log_warn "Fedora requires RPMFusion for v4l2loopback."
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
    log_warn "Dependency installation had issues. Trying to proceed..."
fi

# --- STEP 1.5: SCRCPY CHECK ---
echo -e "\n${GREEN}[Check] Verifying scrcpy version...${NC}"

check_scrcpy() {
    if ! command -v scrcpy &> /dev/null; then echo "0.0"; return; fi
    scrcpy --version 2>/dev/null | head -n 1 | awk '{print $2}'
}

CURRENT_VER=$(check_scrcpy)
REQUIRED_VER="2.0"

if [ "$(printf '%s\n' "$REQUIRED_VER" "$CURRENT_VER" | sort -V | head -n1)" = "$CURRENT_VER" ] && [ "$CURRENT_VER" != "$REQUIRED_VER" ]; then
    log_warn "Scrcpy v$CURRENT_VER is too old (Need v$REQUIRED_VER+)."
    if command -v snap &> /dev/null; then
        log_info "Installing via Snap..."
        sudo snap install scrcpy
        sudo snap connect scrcpy:camera
        sudo snap connect scrcpy:raw-usb
    else
        log_warn "Please manually update scrcpy to v2.0+ for camera support."
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
        log_error "Failed to load module (Secure Boot?)."
        echo "Try rebooting your system."
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
log_info "Waiting for device..."
adb wait-for-usb-device

log_success "Device connected!"
log_info "Detecting Wi-Fi IP address..."

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
    read -p "Enter phone IP manually (e.g., 192.168.1.50): " PHONE_IP
fi

# Enable TCP/IP
adb tcpip 5555
sleep 2

# --- STEP 4: INSTALLING SCRIPTS ---
echo -e "\n${GREEN}[4/5] Installing Control Scripts...${NC}"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

log_info "Installing android-webcam-ctl to $BIN_DIR..."

cat << 'EOF' > "$BIN_DIR/android-webcam-ctl"
#!/bin/bash
# android-webcam-ctl
# Central control script for Android Webcam on Linux

CONFIG_DIR="$HOME/.config/android-webcam"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
LOG_FILE="/tmp/android-cam.log"

# Default configuration values
DEFAULT_CAMERA_FACING="back" # front, back, external
DEFAULT_VIDEO_SIZE=""        # e.g. 1920x1080 (empty = max supported)
DEFAULT_BIT_RATE="8M"
DEFAULT_ARGS="--no-audio --buffer=400"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Config Management ---

load_config() {
    # Ensure config dir exists
    mkdir -p "$CONFIG_DIR"
    
    # Migration from v2.0 (config.env) if settings.conf missing
    if [ ! -f "$CONFIG_FILE" ] && [ -f "$CONFIG_DIR/config.env" ]; then
        source "$CONFIG_DIR/config.env"
        # Extract IP from OLD format (IP:PORT)
        CLEAN_IP=$(echo "$PHONE_IP" | cut -d: -f1)
        
        # Write new config
        cat << END_CONF > "$CONFIG_FILE"
# Android Webcam Configuration
PHONE_IP="$CLEAN_IP"
CAMERA_FACING="$DEFAULT_CAMERA_FACING"
VIDEO_SIZE="$DEFAULT_VIDEO_SIZE"
BIT_RATE="$DEFAULT_BIT_RATE"
EXTRA_ARGS="$DEFAULT_ARGS"
END_CONF
    fi
    
    # Create default if nothing exists
    if [ ! -f "$CONFIG_FILE" ]; then
        cat << END_CONF > "$CONFIG_FILE"
# Android Webcam Configuration
PHONE_IP=""
CAMERA_FACING="$DEFAULT_CAMERA_FACING"
VIDEO_SIZE="$DEFAULT_VIDEO_SIZE"
BIT_RATE="$DEFAULT_BIT_RATE"
EXTRA_ARGS="$DEFAULT_ARGS"
END_CONF
    fi

    source "$CONFIG_FILE"
}

# --- Helpers ---

notify() {
    local level="$1"
    local title="$2"
    local msg="$3"
    local icon="$4"
    if [ -z "$icon" ]; then icon="camera-web"; fi
    notify-send -u "$level" -i "$icon" "$title" "$msg"
}

is_running() {
    pgrep -f "scrcpy.*video-source=camera" > /dev/null
}

find_scrcpy() {
    if command -v scrcpy >/dev/null; then
        echo "$(command -v scrcpy)"
    elif [ -f /snap/bin/scrcpy ]; then
        echo "/snap/bin/scrcpy"
    else
        return 1
    fi
}

# --- Commands ---

cmd_start() {
    load_config
    
    if is_running; then
        echo "Camera is already active."
        notify "low" "Android Camera" "Already active"
        return 0
    fi
    
    if [ -z "$PHONE_IP" ]; then
        echo -e "${RED}Error:${NC} PHONE_IP not set. Run '$0 config' to edit settings."
        notify "critical" "Android Camera" "Config Error: No IP set" "error"
        return 1
    fi

    echo -e "${BLUE}Connecting to $PHONE_IP...${NC}"
    notify "normal" "Android Camera" "⌛ Connecting..."

    # Connection attempt
    adb connect "$PHONE_IP:5555" > /dev/null
    
    SCRCPY_BIN=$(find_scrcpy)
    if [ -z "$SCRCPY_BIN" ]; then
        echo -e "${RED}Error:${NC} scrcpy not found!"
        notify "critical" "Android Camera" "Error: scrcpy not found" "error"
        return 1
    fi

    # Construct the command
    CMD=("$SCRCPY_BIN")
    CMD+=("-s" "$PHONE_IP:5555")
    CMD+=("--video-source=camera")
    CMD+=("--camera-facing=$CAMERA_FACING")
    
    if [ ! -z "$VIDEO_SIZE" ]; then
        CMD+=("--max-size=$VIDEO_SIZE")
    fi
    
    if [ ! -z "$BIT_RATE" ]; then
        CMD+=("--video-bit-rate=$BIT_RATE")
    fi
    
    CMD+=("--v4l2-sink=/dev/video0")
    
    # Split EXTRA_ARGS string into array
    IFS=' ' read -r -a EXTRA_ARGS_ARRAY <<< "$EXTRA_ARGS"
    CMD+=("${EXTRA_ARGS_ARRAY[@]}")

    echo "Executing: ${CMD[*]}"
    
    # Run in background
    nohup "${CMD[@]}" > "$LOG_FILE" 2>&1 &
    PID=$!
    
    sleep 3
    if ps -p $PID > /dev/null; then
        echo -e "${GREEN}Started successfully (PID: $PID)${NC}"
        notify "normal" "Android Camera" "✅ Active (PID: $PID)"
    else
        echo -e "${RED}Failed to start.${NC} Check $LOG_FILE"
        head -n 5 "$LOG_FILE"
        notify "critical" "Camera Error" "Failed to start. Check logs." "error"
    fi
}

cmd_stop() {
    if is_running; then
        pkill -f "scrcpy.*video-source=camera"
        echo -e "${YELLOW}Stopped.${NC}"
        notify "low" "Android Camera" "⏹ Stopped"
    else
        echo "Not running."
    fi
}

cmd_toggle() {
    if is_running; then
        cmd_stop
    else
        cmd_start
    fi
}

cmd_fix() {
    notify-send -i smartphone "Camera Setup" "🔌 Connect USB Cable..." "smartphone"
    echo -e "${BLUE}Waiting for USB device...${NC}"
    adb wait-for-usb-device
    echo "Device connected. Enabling TCP/IP mode..."
    adb tcpip 5555
    echo -e "${GREEN}Done! You can disconnect USB now.${NC}"
    notify-send -i smartphone "Camera Setup" "✅ Fixed! Unplug USB." "smartphone"
}

cmd_status() {
    load_config
    echo -e "--- ${BLUE}Android Camera Status${NC} ---"
    
    if is_running; then
        PID=$(pgrep -f "scrcpy.*video-source=camera")
        echo -e "Status: ${GREEN}Active${NC} (PID: $PID)"
    else
        echo -e "Status: ${RED}Inactive${NC}"
    fi
    
    echo ""
    echo -e "--- ${BLUE}Configuration${NC} ---"
    echo "File: $CONFIG_FILE"
    echo "Phone IP:       ${PHONE_IP:-[Not Set]}"
    echo "Camera Facing:  $CAMERA_FACING"
    echo "Video Size:     ${VIDEO_SIZE:-Max}"
    echo "Bitrate:        $BIT_RATE"
}

cmd_config() {
    load_config
    EDITOR=${EDITOR:-nano}
    $EDITOR "$CONFIG_FILE"
}

# --- Main ---

case "$1" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    toggle) cmd_toggle ;;
    fix)    cmd_fix ;;
    status) cmd_status ;;
    config) cmd_config ;;
    *)
        echo "Usage: $0 {start|stop|toggle|fix|status|config}"
        exit 1
        ;;
esac
EOF

chmod +x "$BIN_DIR/android-webcam-ctl"

# Generate Config
CONFIG_DIR="$HOME/.config/android-webcam"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
mkdir -p "$CONFIG_DIR"

# Only create if doesn't exist to respect user edits on re-install
if [ ! -f "$CONFIG_FILE" ]; then
    log_info "Creating initial configuration..."
    cat << EOF > "$CONFIG_FILE"
# Android Webcam Configuration
PHONE_IP="$PHONE_IP"
CAMERA_FACING="back"
VIDEO_SIZE=""
BIT_RATE="8M"
EXTRA_ARGS="--no-audio --buffer=400"
EOF
else
    log_info "Updating IP in existing config..."
    sed -i "s/PHONE_IP=.*/PHONE_IP=\"$PHONE_IP\"/" "$CONFIG_FILE"
fi

# --- STEP 5: ICONS ---
echo -e "\n${GREEN}[5/5] Creating Launcher Icons...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

cat << EOF > "$APP_DIR/android-cam.desktop"
[Desktop Entry]
Version=1.0
Name=Camera Phone
Comment=Toggle Android Camera
Exec=$BIN_DIR/android-webcam-ctl toggle
Icon=camera-web
Terminal=false
Type=Application
Categories=Utility;Video;
Actions=Status;Config;Fix;

[Desktop Action Status]
Name=Check Status
Exec=bash -c "$BIN_DIR/android-webcam-ctl status; read -p 'Press Enter...' "
Terminal=true

[Desktop Action Config]
Name=Settings
Exec=$BIN_DIR/android-webcam-ctl config

[Desktop Action Fix]
Name=Fix Connection (USB)
Exec=$BIN_DIR/android-webcam-ctl fix
EOF

# Separate Fix Icon (Optional but useful)
cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Fix Camera (USB)
Comment=Reconnect after restart
Exec=$BIN_DIR/android-webcam-ctl fix
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
echo "3. Run 'android-webcam-ctl config' to change settings."
echo ""