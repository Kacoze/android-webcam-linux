#!/bin/bash

# =============================================================================
# 📸 Android Webcam Setup for Linux (Universal)
# =============================================================================
# Transforms your Android device into a low-latency HD webcam for Linux.
# GitHub: https://github.com/Kacoze/android-webcam-linux
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
    
    # Try ping first, fallback to curl if ping is not available
    if command -v ping >/dev/null 2>&1; then
        if ! ping -c 1 8.8.8.8 &> /dev/null; then
            log_error "No internet connection detected (ping failed)."
            exit 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        if ! curl -s --max-time 3 https://www.google.com >/dev/null 2>&1; then
            log_error "No internet connection detected (curl failed)."
            exit 1
        fi
    else
        log_warn "Cannot check internet connection (ping and curl not available)."
        log_warn "Continuing anyway, but installation may fail if internet is required."
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
# Capitalize first letter (compatible with both GNU sed and BSD sed)
DISTRO_CAPITALIZED=$(echo "$DISTRO" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
echo -e "Detected System: ${BLUE}${DISTRO_CAPITALIZED}${NC}"

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

# --- STEP 1.5: SCRCPY INSTALLATION ---
echo -e "\n${GREEN}[Check] Ensuring scrcpy >= 2.0 is available...${NC}"

check_scrcpy_version() {
    local scrcpy_bin="$1"
    if [ -z "$scrcpy_bin" ] || [ ! -x "$scrcpy_bin" ]; then
        echo "0.0"
        return
    fi
    # Portable version parsing (works without grep -P)
    local version_output
    version_output=$("$scrcpy_bin" --version 2>/dev/null || echo "")
    if [ -z "$version_output" ]; then
        echo "0.0"
        return
    fi
    # Extract version using sed (more portable than grep -P)
    echo "$version_output" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0"
}

version_compare() {
    local required="$1"
    local current="$2"
    if [ "$current" = "0.0" ]; then
        return 1
    fi
    # Compare versions using sort -V: check if current >= required
    # If required is the first (smallest) when sorted, then current >= required
    local sorted
    sorted=$(printf '%s\n' "$required" "$current" | sort -V | head -n1)
    [ "$sorted" = "$required" ]
}

ensure_scrcpy() {
    local REQUIRED_VER="2.0"
    local scrcpy_bin=""
    local current_ver="0.0"
    local temp_file=""
    local extract_dir=""
    
    # Cleanup function for temporary files on exit/interrupt
    cleanup_temp_files() {
        if [ ! -z "$extract_dir" ] && [ -d "$extract_dir" ]; then
            rm -rf "$extract_dir" 2>/dev/null
        fi
        if [ ! -z "$temp_file" ] && [ -f "$temp_file" ]; then
            rm -f "$temp_file" 2>/dev/null
        fi
    }
    
    # Set trap for cleanup on interrupt
    trap cleanup_temp_files INT TERM EXIT
    
    # Check if scrcpy already exists and is compatible
    if command -v scrcpy >/dev/null 2>&1; then
        scrcpy_bin=$(command -v scrcpy)
        current_ver=$(check_scrcpy_version "$scrcpy_bin")
        if version_compare "$REQUIRED_VER" "$current_ver"; then
            trap - INT TERM EXIT  # Remove trap before return
            log_success "Found compatible scrcpy v$current_ver at $scrcpy_bin"
            return 0
        else
            log_warn "Existing scrcpy v$current_ver is too old (need v$REQUIRED_VER+)"
        fi
    fi
    
    # Check snap version
    if [ -f /snap/bin/scrcpy ]; then
        scrcpy_bin="/snap/bin/scrcpy"
        current_ver=$(check_scrcpy_version "$scrcpy_bin")
        if version_compare "$REQUIRED_VER" "$current_ver"; then
            trap - INT TERM EXIT  # Remove trap before return
            log_success "Found compatible scrcpy v$current_ver (snap)"
            return 0
        fi
    fi
    
    # Try installing via Snap
    if command -v snap >/dev/null 2>&1; then
        log_info "Attempting to install scrcpy via Snap..."
        if sudo snap install scrcpy 2>/dev/null; then
            sudo snap connect scrcpy:camera 2>/dev/null || true
            sudo snap connect scrcpy:raw-usb 2>/dev/null || true
            sleep 2
            if [ -f /snap/bin/scrcpy ]; then
                scrcpy_bin="/snap/bin/scrcpy"
                current_ver=$(check_scrcpy_version "$scrcpy_bin")
                if version_compare "$REQUIRED_VER" "$current_ver"; then
                    trap - INT TERM EXIT  # Remove trap before return
                    log_success "Installed scrcpy v$current_ver via Snap"
                    return 0
                fi
            fi
        fi
    fi
    
    # Try installing via Flatpak
    if command -v flatpak >/dev/null 2>&1; then
        log_info "Attempting to install scrcpy via Flatpak..."
        if flatpak install -y flathub org.scrcpy.ScrCpy 2>/dev/null; then
            # Verify installation succeeded
            if flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
                scrcpy_bin="flatpak run org.scrcpy.ScrCpy"
                # Flatpak version check
                current_ver=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0")
                if version_compare "$REQUIRED_VER" "$current_ver"; then
                    trap - INT TERM EXIT  # Remove trap before return
                    log_success "Installed scrcpy v$current_ver via Flatpak"
                    return 0
                fi
            fi
        fi
    fi
    
    # Try downloading from GitHub Releases
    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl not found, skipping GitHub download method."
    elif ! command -v tar >/dev/null 2>&1; then
        log_warn "tar not found, skipping GitHub download method."
    elif ! command -v mktemp >/dev/null 2>&1; then
        log_warn "mktemp not found, skipping GitHub download method."
    elif ! command -v find >/dev/null 2>&1; then
        log_warn "find not found, skipping GitHub download method."
    else
        log_info "Attempting to download scrcpy from GitHub Releases..."
        local arch
        arch=$(uname -m)
        case "$arch" in
            x86_64) arch="x86_64" ;;
            aarch64|arm64) arch="arm64" ;;
            armv7l|armv6l) arch="armv7" ;;
            *) arch="x86_64" ;; # fallback
        esac
        
        local download_dir="$HOME/.local/bin"
        mkdir -p "$download_dir"
        
        # Get latest release URL
        # Use sed as fallback if grep -o is not available
        local latest_url
        if echo "test" | grep -o "test" >/dev/null 2>&1; then
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep -o "https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\.tar\.xz" | head -n 1)
        else
            # Fallback using sed (more portable)
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | sed -n "s|.*\"\(https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\.tar\.xz\)\".*|\1|p" | head -n 1)
        fi
        
        if [ ! -z "$latest_url" ]; then
            log_info "Downloading scrcpy from GitHub..."
            temp_file=$(mktemp)
            if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
                log_warn "Failed to create temporary file, skipping GitHub download..."
                cleanup_temp_files
            elif curl -L -f -s "$latest_url" -o "$temp_file" 2>/dev/null; then
                # Validate downloaded file (check size > 0)
                if [ ! -s "$temp_file" ]; then
                    log_warn "Downloaded file is empty, skipping..."
                    cleanup_temp_files
                else
                    extract_dir=$(mktemp -d)
                    if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
                        log_warn "Failed to create temporary directory, skipping..."
                        cleanup_temp_files
                    elif tar -xf "$temp_file" -C "$extract_dir" 2>/dev/null; then
                        # Find scrcpy binary in extracted directory
                        local found_bin
                        found_bin=$(find "$extract_dir" -name "scrcpy" -type f -executable | head -n 1)
                        if [ ! -z "$found_bin" ]; then
                            if ! cp "$found_bin" "$download_dir/scrcpy" 2>/dev/null; then
                                log_warn "Failed to copy scrcpy binary, skipping..."
                                cleanup_temp_files
                            elif ! chmod +x "$download_dir/scrcpy" 2>/dev/null; then
                                log_warn "Failed to make scrcpy executable, skipping..."
                                cleanup_temp_files
                            else
                                scrcpy_bin="$download_dir/scrcpy"
                                current_ver=$(check_scrcpy_version "$scrcpy_bin")
                                if version_compare "$REQUIRED_VER" "$current_ver"; then
                                    cleanup_temp_files
                                    trap - INT TERM EXIT  # Remove trap after success
                                    log_success "Downloaded and installed scrcpy v$current_ver to $download_dir"
                                    return 0
                                fi
                            fi
                        fi
                    fi
                    cleanup_temp_files
                fi
            else
                cleanup_temp_files
            fi
        fi
    fi
    
    # Remove trap before exit
    trap - INT TERM EXIT
    
    # If we get here, nothing worked
    log_error "Failed to install scrcpy >= v$REQUIRED_VER"
    echo ""
    echo "Please install scrcpy manually:"
    echo "  - Snap: sudo snap install scrcpy"
    echo "  - Flatpak: flatpak install flathub org.scrcpy.ScrCpy"
    echo "  - Or download from: https://github.com/Genymobile/scrcpy/releases"
    echo ""
    read -p "Press Enter to continue anyway (camera may not work)..."
    return 1
}

ensure_scrcpy

# --- STEP 2: KERNEL MODULE ---
echo -e "\n${GREEN}[2/5] Configuring V4L2 Module...${NC}"

CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    log_info "Creating module configuration..."
    if ! echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null; then
        log_error "Failed to create module configuration file."
        log_warn "Continuing anyway, but module may not work properly..."
    fi
    if ! echo "v4l2loopback" | sudo tee "$LOAD_FILE" > /dev/null; then
        log_error "Failed to create module load file."
        log_warn "Continuing anyway, but module may not auto-load on boot..."
    fi
    
    log_info "Reloading module..."
    sudo modprobe -r v4l2loopback 2>/dev/null
    if sudo modprobe v4l2loopback; then
        log_success "Module loaded."
        # Verify module is actually loaded
        sleep 1
        if ! lsmod | grep -q v4l2loopback; then
            log_warn "Module may not be loaded properly. Check with: lsmod | grep v4l2loopback"
        fi
    else
        log_error "Failed to load module (Secure Boot?)."
        echo "Try rebooting your system or check Secure Boot settings."
        log_warn "Continuing anyway, but camera may not work..."
    fi
else
    log_success "Module check passed."
    # Verify module is loaded
    if ! lsmod | grep -q v4l2loopback; then
        log_warn "Module configuration exists but module is not loaded."
        log_info "Attempting to load module..."
        if sudo modprobe v4l2loopback; then
            log_success "Module loaded."
        else
            log_warn "Failed to load module. Camera may not work."
        fi
    fi
fi

# --- STEP 3: PHONE PAIRING ---
echo -e "\n${GREEN}[3/5] Pairing Phone...${NC}"

# Check if adb is available
if ! command -v adb >/dev/null 2>&1; then
    log_error "adb not found! Please install android-tools-adb first."
    exit 1
fi

echo "---------------------------------------------------"
echo " 1. USB Connection: YES (Connect cable now)"
echo " 2. USB Debugging:  ENABLED (In Developer Options)"
echo " 3. RSA Prompt:     ACCEPTED (On phone screen)"
echo "---------------------------------------------------"
log_info "Waiting for device..."
if ! adb wait-for-usb-device; then
    log_error "Failed to detect device or operation cancelled."
    exit 1
fi

log_success "Device connected!"
log_info "Detecting Wi-Fi IP address..."

PHONE_IP=""
# Check if awk and cut are available for auto-detection
if command -v awk >/dev/null 2>&1 && command -v cut >/dev/null 2>&1; then
    for iface in wlan0 swlan0 wlan1 wlan2 eth0; do
        IP=$(adb shell ip -4 -o addr show $iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
        if [ ! -z "$IP" ]; then
            PHONE_IP=$IP
            log_success "Found IP ($iface): $PHONE_IP"
            break
        fi
    done
else
    log_warn "awk or cut not found, skipping auto-detection."
fi

if [ -z "$PHONE_IP" ]; then
    log_warn "Could not auto-detect Wi-Fi IP."
    while true; do
        read -p "Enter phone IP manually (e.g., 192.168.1.50): " PHONE_IP
        # Validate IP format
        if [[ "$PHONE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            # Check each octet is 0-255
            IFS='.' read -ra ADDR <<< "$PHONE_IP"
            valid=true
            for i in "${ADDR[@]}"; do
                if [[ $i -lt 0 || $i -gt 255 ]]; then
                    valid=false
                    break
                fi
            done
            if [ "$valid" = true ]; then
                break
            fi
        fi
        log_error "Invalid IP address format. Please try again."
    done
fi

# Enable TCP/IP
if ! adb tcpip 5555; then
    log_error "Failed to enable TCP/IP mode on device."
    exit 1
fi
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
DEFAULT_VIDEO_SIZE=""        # e.g. 1080 (max dimension in pixels, empty = max supported)
DEFAULT_BIT_RATE="8M"
DEFAULT_ARGS="--no-audio --buffer=400"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Cleanup on exit ---
cleanup_on_exit() {
    # Cleanup function for trap (no exit - let script handle exit codes)
    :
}

trap cleanup_on_exit INT TERM

# --- Validation Functions ---

validate_ip() {
    local ip="$1"
    # Basic IPv4 validation regex
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Check each octet is 0-255
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -lt 0 || $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

check_dependencies() {
    local missing=()
    
    if ! command -v adb >/dev/null 2>&1; then
        missing+=("adb")
    fi
    
    local scrcpy_found=false
    if command -v scrcpy >/dev/null 2>&1; then
        scrcpy_found=true
    elif [ -f /snap/bin/scrcpy ]; then
        scrcpy_found=true
    elif [ -f "$HOME/.local/bin/scrcpy" ]; then
        scrcpy_found=true
    elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        scrcpy_found=true
    fi
    
    if [ "$scrcpy_found" = false ]; then
        missing+=("scrcpy")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error:${NC} Missing dependencies: ${missing[*]}"
        echo "Please install them first."
        return 1
    fi
    return 0
}

# --- Config Management ---

load_config() {
    # Ensure config dir exists
    mkdir -p "$CONFIG_DIR"
    
    # Migration from v2.0 (config.env) if settings.conf missing
    if [ ! -f "$CONFIG_FILE" ] && [ -f "$CONFIG_DIR/config.env" ]; then
        if ! source "$CONFIG_DIR/config.env" 2>/dev/null; then
            echo -e "${YELLOW}Warning:${NC} Error loading old config.env, using defaults"
        fi
        # Extract IP from OLD format (IP:PORT)
        # Use sed instead of cut for better compatibility
        CLEAN_IP=$(echo "$PHONE_IP" | sed 's/:.*$//')
        
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

    if ! source "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${RED}Error:${NC} Failed to load configuration file: $CONFIG_FILE"
        echo "Please check the file for syntax errors."
        return 1
    fi
}

# --- Helpers ---

notify() {
    local level="$1"
    local title="$2"
    local msg="$3"
    local icon="$4"
    if [ -z "$icon" ]; then icon="camera-web"; fi
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$level" -i "$icon" "$title" "$msg" 2>/dev/null || true
    else
        # Fallback to echo if notify-send is not available
        echo "[$level] $title: $msg" >&2
    fi
}

is_running() {
    # Check if scrcpy process is running
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "scrcpy.*video-source=camera" > /dev/null
    elif command -v ps >/dev/null 2>&1; then
        ps aux 2>/dev/null | grep -q "[s]crcpy.*video-source=camera"
    else
        # Fallback: try to find process by PID file or return false
        return 1
    fi
}

find_scrcpy() {
    if command -v scrcpy >/dev/null 2>&1; then
        echo "$(command -v scrcpy)"
    elif [ -f /snap/bin/scrcpy ]; then
        echo "/snap/bin/scrcpy"
    elif [ -f "$HOME/.local/bin/scrcpy" ]; then
        echo "$HOME/.local/bin/scrcpy"
    elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        echo "flatpak run org.scrcpy.ScrCpy"
    else
        return 1
    fi
}

# --- Commands ---

cmd_start() {
    # Check dependencies first
    if ! check_dependencies; then
        notify "critical" "Android Camera" "Missing dependencies" "error"
        return 1
    fi
    
    if ! load_config; then
        return 1
    fi
    
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
    
    # Validate IP format
    if ! validate_ip "$PHONE_IP"; then
        echo -e "${RED}Error:${NC} Invalid IP address format: $PHONE_IP"
        notify "critical" "Android Camera" "Invalid IP address" "error"
        return 1
    fi

    echo -e "${BLUE}Connecting to $PHONE_IP...${NC}"
    notify "normal" "Android Camera" "⌛ Connecting..."

    # Connection attempt
    if ! adb connect "$PHONE_IP:5555" > /dev/null 2>&1; then
        echo -e "${RED}Error:${NC} Failed to connect to $PHONE_IP:5555"
        notify "critical" "Android Camera" "Connection failed" "error"
        return 1
    fi
    
    SCRCPY_BIN=$(find_scrcpy)
    if [ -z "$SCRCPY_BIN" ]; then
        echo -e "${RED}Error:${NC} scrcpy not found!"
        notify "critical" "Android Camera" "Error: scrcpy not found" "error"
        return 1
    fi

    # Construct the command
    # Handle Flatpak command which needs to be split into array elements
    if [[ "$SCRCPY_BIN" == "flatpak run"* ]]; then
        # Split "flatpak run org.scrcpy.ScrCpy" into array elements
        IFS=' ' read -r -a FLATPAK_CMD <<< "$SCRCPY_BIN"
        CMD=("${FLATPAK_CMD[@]}")
    else
        CMD=("$SCRCPY_BIN")
    fi
    CMD+=("-s" "$PHONE_IP:5555")
    CMD+=("--video-source=camera")
    CMD+=("--camera-facing=$CAMERA_FACING")
    
    if [ ! -z "$VIDEO_SIZE" ]; then
        # VIDEO_SIZE should be a number (max dimension), not WxH format
        # Extract the largest number from the input (handles both "1080" and "1920x1080" formats)
        local max_dim
        # Remove all non-digits, then find the maximum value
        local digits_only
        digits_only=$(echo "$VIDEO_SIZE" | sed 's/[^0-9]/ /g')
        # Extract all numbers and find the maximum
        max_dim="0"
        for num in $digits_only; do
            if [ ! -z "$num" ] && [ "$num" -gt "$max_dim" ] 2>/dev/null; then
                max_dim="$num"
            fi
        done
        
        if [ ! -z "$max_dim" ] && [ "$max_dim" -gt 0 ] 2>/dev/null; then
            CMD+=("--max-size=$max_dim")
        else
            echo -e "${YELLOW}Warning:${NC} Invalid VIDEO_SIZE format. Use a number (e.g., 1080) or leave empty."
        fi
    fi
    
    if [ ! -z "$BIT_RATE" ]; then
        CMD+=("--video-bit-rate=$BIT_RATE")
    fi
    
    # Check if video device exists
    if [ ! -c /dev/video10 ]; then
        echo -e "${RED}Error:${NC} /dev/video10 not found. v4l2loopback module may not be loaded."
        echo "Try running: sudo modprobe v4l2loopback"
        notify "critical" "Android Camera" "Video device not found" "error"
        return 1
    fi
    
    CMD+=("--v4l2-sink=/dev/video10")
    
    # Parse EXTRA_ARGS safely to prevent command injection
    # Security: Validate and parse without using eval
    if [ ! -z "$EXTRA_ARGS" ]; then
        # Check for dangerous characters that could enable command injection
        if [[ "$EXTRA_ARGS" =~ [\;\|\&\`\$\(\)\<\>] ]]; then
            echo -e "${RED}Error:${NC} EXTRA_ARGS contains unsafe characters (; | & ` $ etc.). Only use scrcpy arguments."
            notify "critical" "Android Camera" "Unsafe config detected" "error"
            return 1
        fi
        
        # Safe parsing: split by spaces and validate each argument
        # This approach is safe because we validate before adding to array
        IFS=' ' read -r -a EXTRA_ARGS_ARRAY <<< "$EXTRA_ARGS"
        for arg in "${EXTRA_ARGS_ARRAY[@]}"; do
            # Remove surrounding quotes if present (safe string manipulation)
            arg="${arg#\"}"
            arg="${arg%\"}"
            arg="${arg#\'}"
            arg="${arg%\'}"
            
            # Additional safety check: ensure no dangerous patterns
            if [[ "$arg" =~ [\;\|\&\`\$] ]]; then
                echo -e "${RED}Error:${NC} Unsafe argument detected: $arg"
                notify "critical" "Android Camera" "Unsafe argument in config" "error"
                return 1
            fi
            
            # Only add non-empty arguments
            if [ ! -z "$arg" ]; then
                CMD+=("$arg")
            fi
        done
    fi

    echo "Executing: ${CMD[*]}"
    
    # Run in background
    local PID=""
    if command -v nohup >/dev/null 2>&1; then
        nohup "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
    elif command -v setsid >/dev/null 2>&1; then
        # Fallback: use setsid if available
        setsid "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
    else
        # Last resort: run in background without nohup
        "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
        disown 2>/dev/null || true
    fi
    
    sleep 3
    # Check if process is still running
    if [ ! -z "$PID" ] && command -v ps >/dev/null 2>&1; then
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "${GREEN}Started successfully (PID: $PID)${NC}"
            notify "normal" "Android Camera" "✅ Active (PID: $PID)"
        else
                echo -e "${RED}Failed to start.${NC} Check $LOG_FILE"
            # Show first 5 lines of log file (use sed as fallback if head is not available)
            if command -v head >/dev/null 2>&1; then
                head -n 5 "$LOG_FILE" 2>/dev/null || true
            elif command -v sed >/dev/null 2>&1; then
                sed -n '1,5p' "$LOG_FILE" 2>/dev/null || true
            else
                echo "Log file: $LOG_FILE"
            fi
            notify "critical" "Camera Error" "Failed to start. Check logs." "error"
        fi
    else
        # ps not available, assume it started
        echo -e "${GREEN}Started (PID: $PID)${NC}"
        notify "normal" "Android Camera" "✅ Active (PID: $PID)"
    fi
}

cmd_stop() {
    if is_running; then
        # Stop scrcpy process
        if command -v pkill >/dev/null 2>&1; then
            pkill -f "scrcpy.*video-source=camera" 2>/dev/null || true
        elif command -v ps >/dev/null 2>&1 && command -v kill >/dev/null 2>&1; then
            # Fallback: find and kill process manually
            local pid
            pid=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | awk '{print $2}' | head -n 1)
            if [ ! -z "$pid" ]; then
                kill "$pid" 2>/dev/null || true
            fi
        else
            echo -e "${YELLOW}Warning:${NC} Cannot stop process (pkill/ps not available)"
            return 1
        fi
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
    if ! command -v adb >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} adb not found!"
        notify "critical" "Camera Setup" "adb not found" "error"
        return 1
    fi
    
    notify "normal" "Camera Setup" "🔌 Connect USB Cable..." "smartphone"
    echo -e "${BLUE}Waiting for USB device...${NC}"
    echo "Press Ctrl+C to cancel"
    
    # Handle interruption
    if ! adb wait-for-usb-device; then
        echo -e "${YELLOW}Cancelled.${NC}"
        notify "low" "Camera Setup" "Cancelled" "smartphone"
        return 1
    fi
    
    echo "Device connected. Enabling TCP/IP mode..."
    if adb tcpip 5555; then
        echo -e "${GREEN}Done! You can disconnect USB now.${NC}"
        notify "normal" "Camera Setup" "✅ Fixed! Unplug USB." "smartphone"
    else
        echo -e "${RED}Error:${NC} Failed to enable TCP/IP mode"
        notify "critical" "Camera Setup" "Failed to enable TCP/IP" "error"
        return 1
    fi
}

cmd_status() {
    if ! load_config; then
        return 1
    fi
    echo -e "--- ${BLUE}Android Camera Status${NC} ---"
    
    if is_running; then
        # Get PID
        local PID=""
        if command -v pgrep >/dev/null 2>&1; then
            PID=$(pgrep -f "scrcpy.*video-source=camera" | head -n 1)
        elif command -v ps >/dev/null 2>&1 && command -v awk >/dev/null 2>&1; then
            PID=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | awk '{print $2}' | head -n 1)
        fi
        if [ ! -z "$PID" ]; then
            echo -e "Status: ${GREEN}Active${NC} (PID: $PID)"
        else
            echo -e "Status: ${GREEN}Active${NC} (PID: unknown)"
        fi
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
    
    # Check dependencies
    echo ""
    echo -e "--- ${BLUE}Dependencies${NC} ---"
    if command -v adb >/dev/null 2>&1; then
        echo -e "adb: ${GREEN}OK${NC}"
    else
        echo -e "adb: ${RED}NOT FOUND${NC}"
    fi
    
    local scrcpy_status="NOT FOUND"
    local scrcpy_path=""
    if command -v scrcpy >/dev/null 2>&1; then
        scrcpy_path=$(command -v scrcpy)
        scrcpy_status="OK"
    elif [ -f /snap/bin/scrcpy ]; then
        scrcpy_path="/snap/bin/scrcpy"
        scrcpy_status="OK"
    elif [ -f "$HOME/.local/bin/scrcpy" ]; then
        scrcpy_path="$HOME/.local/bin/scrcpy"
        scrcpy_status="OK"
    elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        scrcpy_path="flatpak run org.scrcpy.ScrCpy"
        scrcpy_status="OK"
    fi
    
    if [ "$scrcpy_status" = "OK" ]; then
        echo -e "scrcpy: ${GREEN}OK${NC} ($scrcpy_path)"
    else
        echo -e "scrcpy: ${RED}NOT FOUND${NC}"
    fi
}

cmd_config() {
    if ! load_config; then
        return 1
    fi
    
    # Find available editor
    local editor=""
    if [ ! -z "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
        editor="$EDITOR"
    elif command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    else
        echo -e "${RED}Error:${NC} No editor found. Please install nano, vi, or set EDITOR environment variable."
        return 1
    fi
    
    $editor "$CONFIG_FILE"
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

if ! chmod +x "$BIN_DIR/android-webcam-ctl" 2>/dev/null; then
    log_error "Failed to make android-webcam-ctl executable!"
    exit 1
fi

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
    # File exists (we're in the else block), so update it
    if ! sed -i "s|PHONE_IP=.*|PHONE_IP=\"$PHONE_IP\"|" "$CONFIG_FILE" 2>/dev/null; then
        log_warn "Failed to update IP in config file (may be read-only). Creating backup..."
        # Try to create a new file if sed fails
        if [ -w "$CONFIG_FILE" ]; then
            sed "s|PHONE_IP=.*|PHONE_IP=\"$PHONE_IP\"|" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE" 2>/dev/null || log_warn "Could not update config file"
        fi
    fi
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
Terminal=true

[Desktop Action Fix]
Name=Fix Connection (USB)
Exec=$BIN_DIR/android-webcam-ctl fix
Terminal=true
EOF

# Separate Fix Icon (Optional but useful)
cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Fix Camera (USB)
Comment=Reconnect after restart
Exec=$BIN_DIR/android-webcam-ctl fix
Icon=smartphone
Terminal=true
Type=Application
Categories=Utility;Settings;
EOF

# Update desktop database if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" 2>/dev/null || true
fi

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}   ✨ INSTALLATION COMPLETE! ✨          ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "1. Unplug USB Cable."
echo "2. Use 'Camera Phone' icon to toggle webcam."
echo "3. Run 'android-webcam-ctl config' to change settings."
echo ""