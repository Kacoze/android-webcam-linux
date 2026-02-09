#!/bin/bash

# Strict mode: exit on error, undefined variables, and pipe failures
# Note: Some commands intentionally return non-zero (e.g., grep -q), so || true is used where needed
set -euo pipefail

# =============================================================================
# 📸 Android Webcam Setup for Linux (Universal)
# =============================================================================
# Transforms your Android device into a low-latency HD webcam for Linux.
# GitHub: https://github.com/Kacoze/android-webcam-linux
# =============================================================================

# --- CONSTANTS & COLORS ---
readonly SCRIPT_VERSION="2.2.0"
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# --- TTY: safe prompts when run from pipe (e.g. wget -O - ... | bash) ---
PROMPT_FD=0
if [ ! -t 0 ]; then
    if [ ! -e /dev/tty ] || [ ! -r /dev/tty ]; then
        echo -e "${RED}[ERROR]${NC} Running from a pipe without a TTY. Interactive prompts are required."
        echo "Please download the script and run it locally:"
        echo "  wget https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh"
        echo "  bash install.sh"
        exit 1
    fi
    exec 3</dev/tty 2>/dev/null || {
        echo -e "${RED}[ERROR]${NC} Cannot open /dev/tty. Interactive prompts are required."
        echo "Please download the script and run it locally:"
        echo "  wget https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/install.sh"
        echo "  bash install.sh"
        exit 1
    }
    PROMPT_FD=3
    echo -e "${YELLOW}[WARN]${NC} Installation run from pipe; prompts will be read from terminal (/dev/tty)."
fi

prompt_read() { read -u "${PROMPT_FD}" -r -p "$1" "$2"; }
prompt_pause() { read -u "${PROMPT_FD}" -r -p "$1"; }

# --- HELPER FUNCTIONS ---

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}   Android Webcam Setup v${SCRIPT_VERSION}  ${NC}"
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

check_sudo() {
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Consider running as regular user with sudo."
        return 0
    fi
    
    # Check if sudo is available
    if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo not found and not running as root."
        log_error "This script requires administrator privileges."
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires administrator privileges."
        log_info "You will be prompted for your password."
        # Test with a harmless command
        if ! sudo -v; then
            log_error "Failed to obtain sudo privileges."
            exit 1
        fi
    fi
}

check_video_group() {
    # Check if user is in video group
    if command -v groups >/dev/null 2>&1; then
        if ! groups | grep -q video 2>/dev/null; then
            log_warn "User '$USER' is not in 'video' group."
            log_warn "You may not have access to /dev/video* devices."
            echo -e "To fix this, run: ${YELLOW}sudo usermod -aG video $USER${NC}"
            echo -e "Then ${YELLOW}log out and log back in${NC} for changes to take effect."
            sleep 3
        fi
    elif command -v id >/dev/null 2>&1; then
        # Fallback using id command
        if ! id -nG 2>/dev/null | grep -q video 2>/dev/null; then
            log_warn "User '$USER' is not in 'video' group."
            log_warn "You may not have access to /dev/video* devices."
            echo -e "To fix this, run: ${YELLOW}sudo usermod -aG video $USER${NC}"
            echo -e "Then ${YELLOW}log out and log back in${NC} for changes to take effect."
            sleep 3
        fi
    fi
}

validate_ip() {
    local ip="$1"
    # Basic IPv4 validation regex
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Check each octet is 0-255
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if (( 10#$i < 0 || 10#$i > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

uninstall() {
    echo -e "${RED}!!! WARNING !!!${NC}"
    echo "This will remove configuration files, icons, and control scripts."
    prompt_read "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    
    # Verify sudo before removing /usr/local/bin file (avoids silent exit under set -e)
    check_sudo
    
    log_info "Removing files..."
    sudo rm -f /usr/local/bin/android-webcam-ctl
    sudo rm -f /usr/local/bin/android-webcam-common
    sudo rm -f /usr/local/bin/android-webcam-run-in-terminal
    rm -f "$HOME/.local/bin/android-webcam-ctl"   # cleanup legacy (old install location)
    rm -f "$HOME/.local/bin/android-cam-toggle.sh" # cleanup legacy
    rm -f "$HOME/.local/bin/android-cam-fix.sh"    # cleanup legacy
    rm -rf "$HOME/.config/android-webcam"
    rm -f "$HOME/.local/share/applications/android-cam.desktop"
    rm -f "$HOME/.local/share/applications/android-cam-fix.desktop"
    
    log_success "Files removed."
    
    # Optional: remove scrcpy if installed via Snap or Flatpak by this tool
    if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "^scrcpy "; then
        echo "scrcpy is installed via Snap."
        prompt_read "Remove scrcpy (Snap)? (y/N): " snap_confirm
        if [[ "$snap_confirm" == "y" || "$snap_confirm" == "Y" ]]; then
            sudo snap remove scrcpy 2>/dev/null || true
        fi
    fi
    if command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        echo "scrcpy is installed via Flatpak."
        prompt_read "Remove scrcpy (Flatpak)? (y/N): " fp_confirm
        if [[ "$fp_confirm" == "y" || "$fp_confirm" == "Y" ]]; then
            flatpak uninstall -y org.scrcpy.ScrCpy 2>/dev/null || true
        fi
    fi
    
    echo "Do you want to remove system dependencies (scrcpy, v4l2loopback, xvfb etc.)?"
    prompt_read "Remove packages? (y/N): " pkg_confirm
    if [[ "$pkg_confirm" == "y" || "$pkg_confirm" == "Y" ]]; then
        DISTRO=$(detect_distro)
        case "$DISTRO" in
            ubuntu|debian|pop|linuxmint|zorin|kali|neon) sudo apt remove -y scrcpy v4l2loopback-dkms v4l2loopback-utils xvfb ;;
            arch|manjaro) sudo pacman -Rs scrcpy v4l2loopback-dkms xorg-server-xvfb ;;
            fedora) sudo dnf remove -y scrcpy v4l2loopback v4l2loopback-utils xorg-x11-server-Xvfb ;;
            opensuse*|suse) sudo zypper remove -y scrcpy v4l2loopback-kmp-default v4l2loopback-utils xorg-x11-server-extra ;;
            *) echo "Please remove packages manually for your distro." ;;
        esac
    fi
    
    log_success "Uninstallation completed."
    exit 0
}

# --- ARGUMENT PARSING ---
case "${1:-}" in
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
check_sudo
check_internet
check_path
check_video_group

DISTRO=$(detect_distro)
# Capitalize first letter (compatible with both GNU sed and BSD sed)
if command -v awk >/dev/null 2>&1; then
    DISTRO_CAPITALIZED=$(echo "$DISTRO" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
else
    # Fallback: capitalize first letter using sed
    DISTRO_CAPITALIZED=$(echo "$DISTRO" | sed 's/^./\U&/')
fi
echo -e "Detected System: ${BLUE}${DISTRO_CAPITALIZED}${NC}"

# --- STEP 1: DEPENDENCIES ---
echo -e "\n${GREEN}[1/4] Installing System Dependencies...${NC}"

install_deps() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|kali|neon|zorin)
            log_info "Using APT..."
            sudo apt update || return 1
            DEPS=("android-tools-adb" "v4l2loopback-dkms" "v4l2loopback-utils" "ffmpeg" "libnotify-bin" "xvfb")
            sudo apt install -y "${DEPS[@]}" || return 1
            return 0
            ;;
        arch|manjaro|endeavouros|garuda)
            log_info "Using PACMAN..."
            sudo pacman -Sy --needed android-tools v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg libnotify xorg-server-xvfb || return 1
            return 0
            ;;
        fedora|rhel|centos|nobara)
            log_info "Using DNF..."
            if ! dnf repolist | grep -q "rpmfusion"; then
                log_warn "Fedora requires RPMFusion for v4l2loopback."
                prompt_pause "Press Enter to try installing anyway (might fail)..."
            fi
            sudo dnf install -y android-tools v4l2loopback v4l2loopback-utils scrcpy ffmpeg libnotify xorg-x11-server-Xvfb || return 1
            return 0
            ;;
        opensuse*|suse)
            log_info "Using ZYPPER..."
            sudo zypper install -y android-tools v4l2loopback-kmp-default v4l2loopback-utils scrcpy ffmpeg libnotify xorg-x11-server-extra || return 1
            return 0
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            echo "Manual install required: adb, v4l2loopback, scrcpy, ffmpeg, libnotify, xvfb (for headless mode)"
            prompt_pause "Press Enter if you have installed them manually..."
            return 1
            ;;
    esac
}

if ! install_deps; then
    log_error "Dependency installation failed!"
    echo ""
    echo "Critical dependencies may be missing. The installation may fail."
    prompt_read "Do you want to continue anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_error "Installation aborted by user."
        exit 1
    fi
    log_warn "Continuing with potentially missing dependencies..."
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
    if command -v head >/dev/null 2>&1; then
        echo "$version_output" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0"
    else
        echo "$version_output" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | sed -n '1p' || echo "0.0"
    fi
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
    if command -v head >/dev/null 2>&1; then
        sorted=$(printf '%s\n' "$required" "$current" | sort -V | head -n 1)
    else
        sorted=$(printf '%s\n' "$required" "$current" | sort -V | sed -n '1p')
    fi
    [ "$sorted" = "$required" ]
}

# Install scrcpy via Snap
install_scrcpy_snap() {
    local REQUIRED_VER="$1"
    if ! command -v snap >/dev/null 2>&1; then
        return 1
    fi
    
    log_info "Attempting to install scrcpy via Snap..."
    if sudo snap install scrcpy 2>/dev/null; then
        sudo snap connect scrcpy:camera 2>/dev/null || true
        sudo snap connect scrcpy:raw-usb 2>/dev/null || true
        sleep 2
        if [ -f /snap/bin/scrcpy ]; then
            local scrcpy_bin="/snap/bin/scrcpy"
            local current_ver=$(check_scrcpy_version "$scrcpy_bin")
            if version_compare "$REQUIRED_VER" "$current_ver"; then
                log_success "Installed scrcpy v$current_ver via Snap"
                return 0
            fi
        fi
    fi
    return 1
}

# Install scrcpy via Flatpak
install_scrcpy_flatpak() {
    local REQUIRED_VER="$1"
    if ! command -v flatpak >/dev/null 2>&1; then
        return 1
    fi
    
    log_info "Attempting to install scrcpy via Flatpak..."
    if flatpak install -y flathub org.scrcpy.ScrCpy 2>/dev/null; then
        # Verify installation succeeded
        if flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
            local scrcpy_bin="flatpak run org.scrcpy.ScrCpy"
            # Flatpak version check
            local current_ver
            if command -v head >/dev/null 2>&1; then
                current_ver=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0")
            else
                current_ver=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | sed -n '1p' || echo "0.0")
            fi
            if version_compare "$REQUIRED_VER" "$current_ver"; then
                log_success "Installed scrcpy v$current_ver via Flatpak"
                return 0
            fi
        fi
    fi
    return 1
}

# Install scrcpy from GitHub Releases
install_scrcpy_github() {
    local REQUIRED_VER="$1"
    
    # Check required tools
    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl not found, skipping GitHub download method."
        return 1
    fi
    if ! command -v tar >/dev/null 2>&1; then
        log_warn "tar not found, skipping GitHub download method."
        return 1
    fi
    if ! command -v mktemp >/dev/null 2>&1; then
        log_warn "mktemp not found, skipping GitHub download method."
        return 1
    fi
    if ! command -v find >/dev/null 2>&1; then
        log_warn "find not found, skipping GitHub download method."
        return 1
    fi
    
    log_info "Attempting to download scrcpy from GitHub Releases..."
    
    # Detect architecture
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
    local latest_url
    if command -v grep >/dev/null 2>&1; then
        if command -v head >/dev/null 2>&1; then
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep -o "https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\.tar\.[a-z0-9]\+" | head -n 1)
        else
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep -o "https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\.tar\.[a-z0-9]\+" | sed -n '1p')
        fi
    else
        # Fallback using sed (more portable)
        if command -v head >/dev/null 2>&1; then
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | sed -n "s|.*\"\\(https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\\.tar\\.[a-z0-9]\\+\\)\".*|\\1|p" | head -n 1)
        else
            latest_url=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | sed -n "s|.*\"\\(https://github.com/Genymobile/scrcpy/releases/download/[^\"]*scrcpy-.*-linux-${arch}\\.tar\\.[a-z0-9]\\+\\)\".*|\\1|p" | sed -n '1p')
        fi
    fi
    
    if [ -z "$latest_url" ]; then
        return 1
    fi
    
    # Download and extract
    local temp_file extract_dir
    temp_file=$(mktemp)
    if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
        log_warn "Failed to create temporary file, skipping GitHub download..."
        return 1
    fi
    
    # Cleanup function
    cleanup_temp_files() {
        if [ ! -z "$extract_dir" ] && [ -d "$extract_dir" ]; then
            rm -rf "$extract_dir" 2>/dev/null
        fi
        if [ ! -z "$temp_file" ] && [ -f "$temp_file" ]; then
            rm -f "$temp_file" 2>/dev/null
        fi
    }
    
    trap cleanup_temp_files INT TERM EXIT
    
    log_info "Downloading scrcpy from GitHub..."
    if ! curl -L -f -s "$latest_url" -o "$temp_file" 2>/dev/null; then
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    # Validate downloaded file
    if [ ! -s "$temp_file" ]; then
        log_warn "Downloaded file is empty, skipping..."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    extract_dir=$(mktemp -d)
    if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
        log_warn "Failed to create temporary directory, skipping..."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    if ! tar -xf "$temp_file" -C "$extract_dir" 2>/dev/null; then
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    # Find scrcpy binary in extracted directory
    local found_bin
    if command -v head >/dev/null 2>&1; then
        found_bin=$(find "$extract_dir" -name "scrcpy" -type f -executable | head -n 1)
    else
        found_bin=$(find "$extract_dir" -name "scrcpy" -type f -executable | sed -n '1p')
    fi
    
    if [ -z "$found_bin" ]; then
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi

    # Find the server payload (required by scrcpy at runtime).
    # Linux release archives typically include either:
    # - scrcpy-server        (current releases)
    # - scrcpy-server.jar    (older releases / distro builds)
    local found_server=""
    if command -v head >/dev/null 2>&1; then
        found_server=$(find "$extract_dir" -type f \( -name "scrcpy-server" -o -name "scrcpy-server.jar" -o -name "scrcpy-server*" \) ! -name "*.1" | head -n 1)
    else
        found_server=$(find "$extract_dir" -type f \( -name "scrcpy-server" -o -name "scrcpy-server.jar" -o -name "scrcpy-server*" \) ! -name "*.1" | sed -n '1p')
    fi
    if [ -z "$found_server" ]; then
        log_warn "scrcpy server payload not found in release archive. Skipping GitHub method."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    if ! cp "$found_bin" "$download_dir/scrcpy" 2>/dev/null; then
        log_warn "Failed to copy scrcpy binary, skipping..."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    
    if ! chmod +x "$download_dir/scrcpy" 2>/dev/null; then
        log_warn "Failed to make scrcpy executable, skipping..."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi

    # Install server payload next to scrcpy binary so scrcpy can find it.
    # Normalize destination name to what scrcpy expects.
    local server_dest=""
    case "$(basename "$found_server")" in
        *.jar) server_dest="$download_dir/scrcpy-server.jar" ;;
        *)     server_dest="$download_dir/scrcpy-server" ;;
    esac
    if ! cp "$found_server" "$server_dest" 2>/dev/null; then
        log_warn "Failed to copy scrcpy server payload, skipping..."
        cleanup_temp_files
        trap - INT TERM EXIT
        return 1
    fi
    chmod 0644 "$server_dest" 2>/dev/null || true
    
    local scrcpy_bin="$download_dir/scrcpy"
    local current_ver=$(check_scrcpy_version "$scrcpy_bin")
    if version_compare "$REQUIRED_VER" "$current_ver"; then
        cleanup_temp_files
        trap - INT TERM EXIT
        log_success "Downloaded and installed scrcpy v$current_ver (+ server payload) to $download_dir"
        return 0
    fi
    
    cleanup_temp_files
    trap - INT TERM EXIT
    return 1
}

ensure_scrcpy() {
    local REQUIRED_VER="2.0"
    local scrcpy_bin=""
    local current_ver="0.0"
    
    # On Ubuntu/Debian, apt has scrcpy < 2.0; installer will use Snap/Flatpak/GitHub
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|kali|neon|zorin)
            log_info "On Ubuntu/Debian, apt provides scrcpy < 2.0. Installing via Snap, Flatpak, or GitHub..."
            ;;
    esac
    
    # Check if scrcpy already exists and is compatible
    if command -v scrcpy >/dev/null 2>&1; then
        scrcpy_bin=$(command -v scrcpy)
        current_ver=$(check_scrcpy_version "$scrcpy_bin")
        if version_compare "$REQUIRED_VER" "$current_ver"; then
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
            log_success "Found compatible scrcpy v$current_ver (snap)"
            return 0
        fi
    fi
    
    # Try installing via Snap
    if install_scrcpy_snap "$REQUIRED_VER"; then
        return 0
    fi
    
    # Try installing via Flatpak
    if install_scrcpy_flatpak "$REQUIRED_VER"; then
        return 0
    fi
    
    # Try downloading from GitHub Releases
    if install_scrcpy_github "$REQUIRED_VER"; then
        return 0
    fi
    
    # If we get here, nothing worked
    log_error "Failed to install scrcpy >= v$REQUIRED_VER"
    echo ""
    echo "Please install scrcpy manually:"
    echo "  - Snap: sudo snap install scrcpy"
    echo "  - Flatpak: flatpak install flathub org.scrcpy.ScrCpy"
    echo "  - Or download from: https://github.com/Genymobile/scrcpy/releases"
    echo ""
    prompt_read "Do you want to continue installation anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_error "Installation aborted. Please install scrcpy manually and run installer again."
        return 1
    fi
    log_warn "Continuing without scrcpy. Camera will not work until scrcpy is installed."
    return 1
}

if ! ensure_scrcpy; then
    log_error "scrcpy installation failed!"
    echo ""
    prompt_read "Do you want to continue installation anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_error "Installation aborted. Please install scrcpy manually and run installer again."
        exit 1
    fi
    log_warn "Continuing without scrcpy. Camera will not work until scrcpy is installed."
fi

# --- STEP 2: KERNEL MODULE ---
echo -e "\n${GREEN}[2/4] Configuring V4L2 Module...${NC}"

CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    log_info "Creating module configuration..."
    if ! echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null; then
        log_error "Failed to create module configuration file."
        log_warn "Continuing anyway, but module may not work properly..."
    else
        # Verify configuration was created correctly
        if ! grep -q "video_nr=10" "$CONF_FILE" 2>/dev/null; then
            log_warn "Configuration file exists but video_nr is incorrect. Fixing..."
            echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
        fi
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
    # Configuration exists, but verify it has correct video_nr
    if ! grep -q "video_nr=10" "$CONF_FILE" 2>/dev/null; then
        log_warn "Configuration file has incorrect video_nr. Fixing..."
        echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
        log_success "Configuration fixed."
    fi
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

# --- STEP 3: INSTALLING SCRIPTS ---
echo -e "\n${GREEN}[3/4] Installing Control Scripts...${NC}"

BIN_DIR="/usr/local/bin"
sudo mkdir -p "$BIN_DIR"

log_info "Installing android-webcam-common to $BIN_DIR..."

TMP_COMMON=$(mktemp) || { log_error "Failed to create temp file for common."; exit 1; }
cat << 'COMMONEOF' > "$TMP_COMMON"
#!/bin/bash
# android-webcam-common - shared functions for android-webcam-ctl

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if (( 10#$i < 0 || 10#$i > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

check_scrcpy_version() {
    local scrcpy_bin="$1"
    if [ -z "$scrcpy_bin" ] || [ ! -x "$scrcpy_bin" ]; then
        echo "0.0"
        return
    fi
    local version_output
    version_output=$("$scrcpy_bin" --version 2>/dev/null || echo "")
    if [ -z "$version_output" ]; then
        echo "0.0"
        return
    fi
    # Extract version using sed (portable)
    if command -v head >/dev/null 2>&1; then
        echo "$version_output" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0"
    else
        echo "$version_output" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | sed -n '1p' || echo "0.0"
    fi
}

version_compare() {
    # Compare versions using sort -V: check if current >= required
    local required="$1"
    local current="$2"
    if [ "$current" = "0.0" ]; then
        return 1
    fi
    if ! command -v sort >/dev/null 2>&1; then
        # Without sort -V we cannot reliably compare; accept current.
        return 0
    fi
    local smallest
    if command -v head >/dev/null 2>&1; then
        smallest=$(printf '%s\n' "$required" "$current" | sort -V | head -n 1)
    else
        smallest=$(printf '%s\n' "$required" "$current" | sort -V | sed -n '1p')
    fi
    [ "$smallest" = "$required" ]
}

scrcpy_is_compatible() {
    local bin="$1"
    local required="2.0"
    local current
    current=$(check_scrcpy_version "$bin")
    version_compare "$required" "$current"
}

find_scrcpy() {
    # Prefer the self-installed GitHub fallback (and generally newer builds),
    # then Snap, then system PATH, then Flatpak.
    if [ -x "$HOME/.local/bin/scrcpy" ] && scrcpy_is_compatible "$HOME/.local/bin/scrcpy"; then
        echo "$HOME/.local/bin/scrcpy"
        return 0
    fi
    if [ -x /snap/bin/scrcpy ] && scrcpy_is_compatible "/snap/bin/scrcpy"; then
        echo "/snap/bin/scrcpy"
        return 0
    fi
    if command -v scrcpy >/dev/null 2>&1; then
        local path_bin
        path_bin="$(command -v scrcpy)"
        if [ -x "$path_bin" ] && scrcpy_is_compatible "$path_bin"; then
            echo "$path_bin"
            return 0
        fi
    fi
    if command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        # Flatpak version check (best-effort)
        local v="0.0"
        if command -v head >/dev/null 2>&1; then
            v=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | head -n 1 || echo "0.0")
        else
            v=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\?\).*/\1/p' | sed -n '1p' || echo "0.0")
        fi
        if version_compare "2.0" "$v"; then
            echo "flatpak run org.scrcpy.ScrCpy"
            return 0
        fi
    fi
    return 1
}
COMMONEOF
if ! sudo install -m 0644 "$TMP_COMMON" "$BIN_DIR/android-webcam-common"; then
    log_error "Failed to install android-webcam-common to $BIN_DIR!"
    rm -f "$TMP_COMMON"
    exit 1
fi
rm -f "$TMP_COMMON"

log_info "Installing android-webcam-run-in-terminal to $BIN_DIR..."

TMP_RUNTERM=$(mktemp) || { log_error "Failed to create temp file for run-in-terminal."; exit 1; }
cat << 'RUNTERMEOF' > "$TMP_RUNTERM"
#!/bin/bash
# android-webcam-run-in-terminal - run android-webcam-ctl status/config/setup in a terminal (for desktop actions)

set -e
CTL="/usr/local/bin/android-webcam-ctl"
case "${1:-}" in
    status)  CMD="$CTL status; read -r -p \"Press Enter to close...\"; exec bash" ;;
    config)  CMD="$CTL config" ;;
    setup)   CMD="$CTL setup" ;;
    *)       echo "Usage: $0 {status|config|setup}" >&2; exit 1 ;;
esac

run_in_term() {
    local cmd="$1"
    export AWRT_CMD="$cmd"
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        xdg-terminal-exec bash -c "$cmd"
        return $?
    fi
    if command -v x-terminal-emulator >/dev/null 2>&1; then
        x-terminal-emulator -e bash -c "$cmd"
        return $?
    fi
    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal -- bash -c "$cmd"
        return $?
    fi
    if command -v konsole >/dev/null 2>&1; then
        konsole -e bash -c "$cmd"
        return $?
    fi
    if command -v xfce4-terminal >/dev/null 2>&1; then
        xfce4-terminal -e 'bash -c "$AWRT_CMD"'
        return $?
    fi
    if command -v mate-terminal >/dev/null 2>&1; then
        mate-terminal -e 'bash -c "$AWRT_CMD"'
        return $?
    fi
    if command -v xterm >/dev/null 2>&1; then
        xterm -e bash -c "$cmd"
        return $?
    fi
    echo "No terminal emulator found. Install one of: gnome-terminal, konsole, xfce4-terminal, xterm." >&2
    return 1
}

run_in_term "$CMD"
RUNTERMEOF
if ! sudo install -m 0755 "$TMP_RUNTERM" "$BIN_DIR/android-webcam-run-in-terminal"; then
    log_error "Failed to install android-webcam-run-in-terminal to $BIN_DIR!"
    rm -f "$TMP_RUNTERM"
    exit 1
fi
rm -f "$TMP_RUNTERM"

log_info "Installing android-webcam-ctl to $BIN_DIR..."

TMP_CTL=$(mktemp) || { log_error "Failed to create temp file."; exit 1; }
trap 'rm -f "$TMP_CTL"' EXIT

cat << 'EOF' > "$TMP_CTL"
#!/bin/bash
# android-webcam-ctl
# Central control script for Android Webcam on Linux

CONFIG_DIR="$HOME/.config/android-webcam"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
LOG_FILE="/tmp/android-cam.log"
PID_FILE="$CONFIG_DIR/scrcpy.pid"

# Default configuration values
DEFAULT_CAMERA_FACING="back" # front, back, external
DEFAULT_VIDEO_SIZE=""        # e.g. 1080 (max dimension in pixels, empty = max supported)
DEFAULT_BIT_RATE="8M"
DEFAULT_ARGS="--no-audio --v4l2-buffer=400"
DEFAULT_RELOAD_V4L2_ON_STOP="true"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load shared functions (validate_ip, find_scrcpy)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/android-webcam-common" ]; then
    echo -e "${RED}Error:${NC} android-webcam-common not found. Reinstall the tool."
    exit 1
fi
. "$SCRIPT_DIR/android-webcam-common"

# --- Cleanup on exit ---
cleanup_on_exit() {
    # Cleanup function for trap (no exit - let script handle exit codes)
    :
}

trap cleanup_on_exit INT TERM

# --- Validation / Helpers ---

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
            PHONE_IP=""
        fi
        # Extract IP from OLD format (IP:PORT) if PHONE_IP is set
        if [ ! -z "$PHONE_IP" ]; then
            CLEAN_IP=$(echo "$PHONE_IP" | sed 's/:.*$//')
        else
            CLEAN_IP=""
        fi
        
        # Write new config
        cat << END_CONF > "$CONFIG_FILE"
# Android Webcam Configuration
PHONE_IP="$CLEAN_IP"
CAMERA_FACING="$DEFAULT_CAMERA_FACING"
VIDEO_SIZE="$DEFAULT_VIDEO_SIZE"
BIT_RATE="$DEFAULT_BIT_RATE"
EXTRA_ARGS="$DEFAULT_ARGS"
SHOW_WINDOW="true"
RELOAD_V4L2_ON_STOP="$DEFAULT_RELOAD_V4L2_ON_STOP"
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
SHOW_WINDOW="true"
RELOAD_V4L2_ON_STOP="$DEFAULT_RELOAD_V4L2_ON_STOP"
END_CONF
    fi

    if ! source "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${RED}Error:${NC} Failed to load configuration file: $CONFIG_FILE"
        echo "Please check the file for syntax errors."
        return 1
    fi
    # Default for existing configs without SHOW_WINDOW or RELOAD_V4L2_ON_STOP
    SHOW_WINDOW="${SHOW_WINDOW:-true}"
    RELOAD_V4L2_ON_STOP="${RELOAD_V4L2_ON_STOP:-$DEFAULT_RELOAD_V4L2_ON_STOP}"
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
    # Prefer PID file (reliable for Flatpak/Snap/normal)
    if [ -f "$PID_FILE" ]; then
        local pid
        read -r pid < "$PID_FILE" 2>/dev/null
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$PID_FILE" 2>/dev/null
    fi
    # Fallback: pgrep/ps (may miss Flatpak process name)
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "scrcpy.*video-source=camera" > /dev/null
    elif command -v ps >/dev/null 2>&1; then
        ps aux 2>/dev/null | grep -q "[s]crcpy.*video-source=camera"
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
        echo -e "${BLUE}Phone IP not set. Running setup (connect USB when prompted)...${NC}"
        notify "normal" "Android Camera" "Running setup – connect USB when prompted" "camera-web"
        cmd_fix
        if ! load_config; then
            return 1
        fi
        if [ -z "$PHONE_IP" ]; then
            echo -e "${RED}Error:${NC} PHONE_IP not set. Run '$0 setup' or '$0 config' to set it."
            notify "critical" "Android Camera" "Config Error: No IP set" "error"
            return 1
        fi
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
            if [ ! -z "$num" ] && (( 10#$num > 10#$max_dim )) 2>/dev/null; then
                max_dim="$num"
            fi
        done
        
        if [ ! -z "$max_dim" ] && (( 10#$max_dim > 0 )) 2>/dev/null; then
            CMD+=("--max-size=$max_dim")
        else
            echo -e "${YELLOW}Warning:${NC} Invalid VIDEO_SIZE format. Use a number (e.g., 1080) or leave empty."
        fi
    fi
    
    if [ ! -z "$BIT_RATE" ]; then
        CMD+=("--video-bit-rate=$BIT_RATE")
    fi
    
    # Check if video device exists, try to load/reload module if missing
    if [ ! -c /dev/video10 ]; then
        echo -e "${YELLOW}Warning:${NC} /dev/video10 not found. Attempting to fix v4l2loopback module..."
        notify "normal" "Android Camera" "Fixing video module..." "camera-web"
        
        # Check if sudo is available
        if ! command -v sudo >/dev/null 2>&1; then
            echo -e "${RED}Error:${NC} sudo not available. Cannot load module automatically."
            echo "Please run: sudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1"
            notify "critical" "Android Camera" "Video device not found" "error"
            return 1
        fi
        
        # Check if sudo can work without password
        local sudo_nopasswd=false
        if sudo -n true 2>/dev/null; then
            sudo_nopasswd=true
        fi
        
        # Check if module is loaded
        local module_loaded=false
        if lsmod | grep -q v4l2loopback 2>/dev/null; then
            module_loaded=true
            echo -e "${BLUE}Module is loaded but /dev/video10 missing. Attempting to fix...${NC}"
        else
            echo -e "${BLUE}Module not loaded. Loading with correct parameters...${NC}"
        fi
        
        # Always fix configuration first (even if file exists)
        echo -e "${BLUE}Ensuring configuration is correct...${NC}"
        if command -v sudo >/dev/null 2>&1; then
            echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee /etc/modprobe.d/v4l2loopback.conf > /dev/null 2>&1
            echo -e "${GREEN}Configuration verified.${NC}"
        fi
        
        # Try to reload/load module using configuration file first
        local success=false
        if [ "$module_loaded" = true ]; then
            # Try to unload module first (only if sudo doesn't require password)
            if [ "$sudo_nopasswd" = true ]; then
                echo -e "${BLUE}Attempting to unload module...${NC}"
                if sudo modprobe -r v4l2loopback 2>/dev/null; then
                    echo -e "${GREEN}Module unloaded.${NC}"
                    sleep 2
                else
                    echo -e "${YELLOW}Warning: Could not unload module (may be in use). Trying alternative approach...${NC}"
                    sleep 1
                fi
            else
                # Sudo requires password - try to load additional device without unloading
                echo -e "${YELLOW}Note: sudo requires password. Trying to create additional device without unloading module...${NC}"
                echo -e "${BLUE}Attempting to load module with multiple devices (devices=2 video_nr=0,10)...${NC}"
                if sudo modprobe v4l2loopback devices=2 video_nr=0,10 card_label="Android Cam","Android Cam" exclusive_caps=1,1 2>/dev/null; then
                    sleep 3
                    if [ -c /dev/video10 ]; then
                        success=true
                        echo -e "${GREEN}Additional device /dev/video10 created successfully.${NC}"
                        notify "normal" "Android Camera" "Module loaded" "camera-web"
                    else
                        echo -e "${YELLOW}Module load command succeeded but /dev/video10 not found.${NC}"
                    fi
                else
                    echo -e "${YELLOW}Could not load module with multiple devices (requires password or module doesn't support it).${NC}"
                fi
            fi
        fi
        
        # Try loading with configuration file (only if module was unloaded or not loaded)
        if [ "$success" = false ] && [ "$module_loaded" = false ] || [ "$sudo_nopasswd" = true ]; then
            if [ -f /etc/modprobe.d/v4l2loopback.conf ]; then
                echo -e "${BLUE}Loading module using configuration file...${NC}"
                if sudo modprobe v4l2loopback 2>/dev/null; then
                    sleep 3
                    # Verify module is actually loaded
                    if lsmod | grep -q v4l2loopback 2>/dev/null; then
                        if [ -c /dev/video10 ]; then
                            success=true
                            echo -e "${GREEN}Module loaded successfully using configuration file.${NC}"
                            notify "normal" "Android Camera" "Module loaded" "camera-web"
                        else
                            echo -e "${YELLOW}Module loaded but /dev/video10 not found. Checking existing devices...${NC}"
                            if command -v ls >/dev/null 2>&1; then
                                echo "Existing video devices:"
                                ls -la /dev/video* 2>/dev/null || echo "No video devices found"
                            fi
                        fi
                    else
                        echo -e "${YELLOW}Module load command succeeded but module not found in lsmod.${NC}"
                    fi
                else
                    echo -e "${YELLOW}Failed to load module using configuration file.${NC}"
                fi
            fi
        fi
        
        # If configuration didn't work, try direct parameters (only if module was unloaded or not loaded)
        if [ "$success" = false ] && ([ "$module_loaded" = false ] || [ "$sudo_nopasswd" = true ]); then
            echo -e "${BLUE}Trying to load module with direct parameters...${NC}"
            if sudo modprobe v4l2loopback video_nr=10 card_label="Android Cam" exclusive_caps=1 2>/dev/null; then
                sleep 3
                # Verify module is loaded
                if lsmod | grep -q v4l2loopback 2>/dev/null; then
                    if [ -c /dev/video10 ]; then
                        success=true
                        echo -e "${GREEN}Module loaded successfully with direct parameters.${NC}"
                        notify "normal" "Android Camera" "Module loaded" "camera-web"
                    else
                        echo -e "${YELLOW}Module loaded but /dev/video10 not found. Checking existing devices...${NC}"
                        if command -v ls >/dev/null 2>&1; then
                            echo "Existing video devices:"
                            ls -la /dev/video* 2>/dev/null || echo "No video devices found"
                        fi
                    fi
                else
                    echo -e "${YELLOW}Module load command succeeded but module not found in lsmod.${NC}"
                fi
            else
                echo -e "${YELLOW}Failed to load module. This may require administrator privileges or Secure Boot may be enabled.${NC}"
            fi
        fi
        
        # Final check
        if [ "$success" = false ] || [ ! -c /dev/video10 ]; then
            echo -e "${RED}Error:${NC} Failed to create /dev/video10."
            echo ""
            echo "Diagnostic information:"
            echo "--- Module status ---"
            if lsmod | grep -q v4l2loopback 2>/dev/null; then
                echo "Module is loaded: $(lsmod | grep v4l2loopback | head -1)"
            else
                echo "Module is NOT loaded"
            fi
            echo ""
            echo "--- Existing video devices ---"
            if command -v ls >/dev/null 2>&1; then
                ls -la /dev/video* 2>/dev/null || echo "No video devices found"
            else
                echo "Cannot list video devices (ls not available)"
            fi
            echo ""
            echo "--- Module configuration ---"
            if [ -f /etc/modprobe.d/v4l2loopback.conf ]; then
                cat /etc/modprobe.d/v4l2loopback.conf
            else
                echo "Configuration file does not exist"
            fi
            echo ""
            echo "Troubleshooting steps:"
            if [ "$sudo_nopasswd" = false ]; then
                echo "1. Sudo requires password. You need to manually fix this:"
                echo "   sudo modprobe -r v4l2loopback"
                echo "   sudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1"
                echo "   OR configure sudo to work without password for modprobe commands"
            else
                echo "1. Try unloading and reloading manually:"
                echo "   sudo modprobe -r v4l2loopback"
                echo "   sudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1"
            fi
            echo "2. Check if /dev/video10 was created: ls -la /dev/video10"
            echo "3. If Secure Boot is enabled, you may need to disable it or sign the module"
            echo "4. If module cannot be unloaded, try rebooting the system"
            if [ "$module_loaded" = true ] && [ "$sudo_nopasswd" = false ]; then
                echo ""
                echo "Note: Module is already loaded but with wrong parameters. Since sudo requires"
                echo "password, automatic fix is not possible. Please run the commands above manually."
            fi
            
            # Prepare notification message with instructions
            local notify_msg=""
            if [ "$sudo_nopasswd" = false ]; then
                notify_msg="Sudo requires password. Run manually:\nsudo modprobe -r v4l2loopback\nsudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1"
            else
                notify_msg="Run manually:\nsudo modprobe -r v4l2loopback\nsudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1"
            fi
            
            # Send notification with instructions
            local short_msg=""
            if [ "$sudo_nopasswd" = false ]; then
                short_msg="Video device not found. Sudo requires password - run commands manually (see dialog/terminal)"
            else
                short_msg="Video device not found. Check terminal for fix instructions"
            fi
            notify "critical" "Android Camera" "$short_msg" "error"
            
            # Try to show instructions in a dialog if available
            if command -v zenity >/dev/null 2>&1; then
                zenity --error --title="Android Camera - Video Device Not Found" --text="Failed to create /dev/video10.

Module is loaded but with wrong parameters.

To fix this, run in terminal:
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1

Or reboot your system." 2>/dev/null || true
            elif command -v kdialog >/dev/null 2>&1; then
                kdialog --error "Failed to create /dev/video10.

Module is loaded but with wrong parameters.

To fix this, run in terminal:
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1

Or reboot your system." 2>/dev/null || true
            else
                # Fallback: send another notification with more details
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send -u critical -i error -t 10000 "Android Camera - Fix Required" "Run: sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback video_nr=10" 2>/dev/null || true
                fi
            fi
            
            return 1
        fi
    fi
    
    CMD+=("--v4l2-sink=/dev/video10")
    
    # Optional: run without camera window (headless; image only to v4l2)
    local show_window_lower
    show_window_lower=$(echo "${SHOW_WINDOW:-true}" | tr '[:upper:]' '[:lower:]')
    if [[ "$show_window_lower" == "false" || "$show_window_lower" == "0" || "$show_window_lower" == "no" ]]; then
        if [[ -z "$EXTRA_ARGS" || "$EXTRA_ARGS" != *"--no-video-playback"* ]]; then
            CMD+=("--no-video-playback")
        fi
    fi
    
    # Parse EXTRA_ARGS safely to prevent command injection
    # Security: Validate and parse without using eval
    if [ ! -z "$EXTRA_ARGS" ]; then
        # Convert deprecated --buffer= to --v4l2-buffer= for backward compatibility
        if [[ "$EXTRA_ARGS" =~ --buffer= ]]; then
            EXTRA_ARGS=$(echo "$EXTRA_ARGS" | sed 's/--buffer=/--v4l2-buffer=/g')
            echo -e "${YELLOW}Note:${NC} Converted deprecated --buffer= to --v4l2-buffer= for scrcpy compatibility"
        fi
        
        # Check for dangerous characters that could enable command injection
        if [[ "$EXTRA_ARGS" =~ [\;\|\&\`\$\(\)\<\>] ]]; then
            echo -e "${RED}Error:${NC} EXTRA_ARGS contains unsafe characters (; | & \` $ etc.). Only use scrcpy arguments."
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
    
    # When headless (SHOW_WINDOW=false), scrcpy still creates a placeholder window with logo; run inside Xvfb so it's not visible
    local RUNNER_ARRAY=(env "SDL_VIDEO_WAYLAND_APP_ID=android-cam")
    if [[ "$show_window_lower" == "false" || "$show_window_lower" == "0" || "$show_window_lower" == "no" ]]; then
        if command -v xvfb-run >/dev/null 2>&1; then
            RUNNER_ARRAY=(xvfb-run -a -s "-screen 0 1x1x24" -- env "SDL_VIDEO_WAYLAND_APP_ID=android-cam")
        fi
    fi
    
    # Run in background (SDL_VIDEO_WAYLAND_APP_ID so Wayland taskbar groups window with Camera Phone icon)
    local PID=""
    if command -v nohup >/dev/null 2>&1; then
        "${RUNNER_ARRAY[@]}" nohup "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
    elif command -v setsid >/dev/null 2>&1; then
        "${RUNNER_ARRAY[@]}" setsid "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
    else
        "${RUNNER_ARRAY[@]}" "${CMD[@]}" > "$LOG_FILE" 2>&1 &
        PID=$!
        disown 2>/dev/null || true
    fi
    
    # Write PID file for reliable stop (Flatpak/Snap/normal)
    if [ ! -z "$PID" ]; then
        mkdir -p "$CONFIG_DIR"
        echo "$PID" > "$PID_FILE" 2>/dev/null || true
    fi
    
    sleep 3
    # Check if process is still running
    if [ ! -z "$PID" ] && command -v ps >/dev/null 2>&1; then
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${GREEN}Started successfully (PID: $PID)${NC}"
            notify "normal" "Android Camera" "✅ Active (PID: $PID)"
            if [[ "$show_window_lower" == "false" || "$show_window_lower" == "0" || "$show_window_lower" == "no" ]]; then
                notify "normal" "Android Camera" "Camera runs in background (no window). To stop: right-click icon → Stop Camera." "camera-web"
            fi
        else
            rm -f "$PID_FILE" 2>/dev/null
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
        if [[ "$show_window_lower" == "false" || "$show_window_lower" == "0" || "$show_window_lower" == "no" ]]; then
            notify "normal" "Android Camera" "Camera runs in background (no window). To stop: right-click icon → Stop Camera." "camera-web"
        fi
    fi
}

cmd_stop() {
    local was_running=false
    is_running && was_running=true

    # Prefer PID file (reliable for Flatpak/Snap/normal)
    if [ -f "$PID_FILE" ]; then
        local pid
        read -r pid < "$PID_FILE" 2>/dev/null
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE" 2>/dev/null
    fi
    # Fallback: pkill/pgrep if still running (e.g. no PID file)
    if is_running; then
        if command -v pkill >/dev/null 2>&1; then
            pkill -f "scrcpy.*video-source=camera" 2>/dev/null || true
        elif command -v ps >/dev/null 2>&1 && command -v kill >/dev/null 2>&1; then
            local pid
            if command -v awk >/dev/null 2>&1; then
                pid=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | awk '{print $2}' | head -n 1)
            else
                pid=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | tr -s ' ' | cut -d' ' -f2 | head -n 1)
            fi
            [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
        fi
    fi

    # Reload v4l2loopback so device is in clean state for next start (fixes Meet/Zoom not seeing camera after stop+start)
    if $was_running; then
        load_config 2>/dev/null || true
        reload_opt="${RELOAD_V4L2_ON_STOP:-true}"
        reload_lower=$(echo "$reload_opt" | tr '[:upper:]' '[:lower:]')
        if [[ "$reload_lower" != "false" && "$reload_lower" != "0" && "$reload_lower" != "no" ]]; then
            if lsmod 2>/dev/null | grep -q v4l2loopback; then
                local reload_ok=false
                # Give scrcpy time to fully release /dev/video10 before unloading module
                sleep 2
                if command -v pkexec >/dev/null 2>&1; then
                    if pkexec sh -c "modprobe -r v4l2loopback 2>/dev/null; modprobe v4l2loopback" 2>/dev/null; then
                        reload_ok=true
                    fi
                fi
                if [ "$reload_ok" = false ] && command -v sudo >/dev/null 2>&1; then
                    sudo sh -c "modprobe -r v4l2loopback 2>/dev/null; modprobe v4l2loopback" 2>/dev/null && reload_ok=true
                fi
                if [ "$reload_ok" = true ]; then
                    sleep 1
                else
                    notify "normal" "Android Camera" "Could not reload video module. If Meet/Zoom does not see the camera next time, click Stop again and enter the password prompt (if shown) or reboot." "dialog-warning"
                fi
            fi
        fi
    fi

    if $was_running; then
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
    
    adb disconnect 2>/dev/null || true
    notify "normal" "Camera Setup" "🔌 Connect USB Cable..." "smartphone"
    echo -e "${BLUE}Waiting for USB device...${NC}"
    echo "Press Ctrl+C to cancel"
    
    # Handle interruption
    local wait_timeout
    wait_timeout="${ADB_WAIT_TIMEOUT:-60}"
    if command -v timeout >/dev/null 2>&1; then
        if ! timeout "$wait_timeout" adb wait-for-usb-device; then
            echo -e "${YELLOW}Cancelled or timed out waiting for USB device.${NC}"
            echo "Tip: Set ADB_WAIT_TIMEOUT (seconds) to change this timeout."
            notify "low" "Camera Setup" "Cancelled or timed out" "smartphone"
            return 1
        fi
    else
        if ! adb wait-for-usb-device; then
            echo -e "${YELLOW}Cancelled.${NC}"
            notify "low" "Camera Setup" "Cancelled" "smartphone"
            return 1
        fi
    fi
    
    # Get USB device ID (in case there are multiple devices - any state: device, unauthorized, offline)
    local usb_device_id=""
    local total_count
    total_count=$(adb devices 2>/dev/null | grep -v "List" | grep -E '\t' | wc -l 2>/dev/null || echo "0")
    total_count=$(echo "$total_count" | tr -d '\n\r' | head -n 1)
    [ -z "$total_count" ] || ! [[ "$total_count" =~ ^[0-9]+$ ]] && total_count="0"
    if [ "$total_count" -gt 1 ]; then
        local device_list
        device_list=$(adb devices 2>/dev/null | grep -v "List" | grep -E '\tdevice$')
        local devices=()
        local line serial
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            serial=$(echo "$line" | awk '{print $1}' | tr -d '[:space:]')
            [ -n "$serial" ] && devices+=( "$serial" )
        done <<< "$device_list"
        local num_devices=${#devices[@]}
        if [ "$num_devices" -eq 0 ]; then
            :
        elif [ "$num_devices" -eq 1 ]; then
            usb_device_id="${devices[0]}"
            echo -e "${BLUE}Using device: $usb_device_id${NC}"
        else
            echo -e "${BLUE}Multiple devices in \"device\" state. Select one:${NC}"
            local i
            for i in "${!devices[@]}"; do
                echo "  $((i+1))) ${devices[i]}"
            done
            local choice
            while true; do
                read -r -p "Your choice (number or serial, Enter = 1): " choice
                choice=$(echo "$choice" | tr -d '[:space:]')
                if [ -z "$choice" ]; then
                    usb_device_id="${devices[0]}"
                    break
                fi
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_devices" ] 2>/dev/null; then
                    usb_device_id="${devices[choice-1]}"
                    break
                fi
                for i in "${!devices[@]}"; do
                    if [ "$choice" = "${devices[i]}" ]; then
                        usb_device_id="${devices[i]}"
                        break 2
                    fi
                done
                echo -e "${RED}Invalid choice. Enter a number 1-$num_devices or the device serial.${NC}"
            done
            if [ -n "$usb_device_id" ]; then
                echo -e "${BLUE}Using device: $usb_device_id${NC}"
            fi
        fi
    fi
    
    # Fallback: if still empty but multiple devices total, use first device in "device" state
    if [ -z "$usb_device_id" ] && [ "$total_count" -gt 1 ] 2>/dev/null; then
        usb_device_id=$(adb devices 2>/dev/null | grep -v "List" | grep -E '\tdevice$' | head -n 1 | awk '{print $1}' | tr -d '[:space:]')
    fi
    
    # Final check: right before tcpip, re-read device list (may have changed since wait-for-usb)
    if [ -z "$usb_device_id" ]; then
        local device_count_now
        device_count_now=$(adb devices 2>/dev/null | grep -v "List" | grep -c -E '\tdevice$' 2>/dev/null || echo "0")
        device_count_now=$(echo "$device_count_now" | tr -d '\n\r' | head -n 1)
        [[ "$device_count_now" =~ ^[0-9]+$ ]] && [ "$device_count_now" -gt 1 ] 2>/dev/null && \
            usb_device_id=$(adb devices 2>/dev/null | grep -v "List" | grep -E '\tdevice$' | head -n 1 | awk '{print $1}' | tr -d '[:space:]')
    fi
    
    # Unconditional safety: never run "adb tcpip" without -s when multiple devices are present
    local device_count_final
    device_count_final=$(adb devices 2>/dev/null | grep -v "List" | grep -c -E '\tdevice$' 2>/dev/null || echo "0")
    device_count_final=$(echo "$device_count_final" | tr -d '\n\r' | head -n 1)
    if [[ "$device_count_final" =~ ^[0-9]+$ ]] && [ "$device_count_final" -ge 2 ] 2>/dev/null; then
        if [ -z "$usb_device_id" ]; then
            usb_device_id=$(adb devices 2>/dev/null | grep -v "List" | grep -E '\tdevice$' | head -n 1 | awk '{print $1}' | tr -d '[:space:]')
        fi
        if [ -n "$usb_device_id" ]; then
            echo -e "${BLUE}Using device: $usb_device_id${NC}"
        fi
    fi
    
    local detected_ip=""
    if command -v awk >/dev/null 2>&1 && command -v cut >/dev/null 2>&1; then
        for iface in wlan0 swlan0 wlan1 wlan2 wifi0; do
            local ip_val=""
            if [ -n "$usb_device_id" ]; then
                ip_val=$(adb -s "$usb_device_id" shell ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | tr -d '[:space:]' || true)
            else
                ip_val=$(adb shell ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | tr -d '[:space:]' || true)
            fi
            if [ -n "$ip_val" ] && validate_ip "$ip_val"; then
                detected_ip="$ip_val"
                break
            fi
        done
        if [ -z "$detected_ip" ]; then
            local all_ips=""
            if [ -n "$usb_device_id" ]; then
                all_ips=$(adb -s "$usb_device_id" shell ip -4 -o addr show 2>/dev/null | awk '{print $2":"$4}' | cut -d: -f1,2 | cut -d/ -f1 || true)
            else
                all_ips=$(adb shell ip -4 -o addr show 2>/dev/null | awk '{print $2":"$4}' | cut -d: -f1,2 | cut -d/ -f1 || true)
            fi
            while IFS= read -r line || [ -n "$line" ]; do
                [ -z "$line" ] && continue
                local iface_name ip_part
                iface_name=$(echo "$line" | cut -d: -f1 | tr -d '[:space:]')
                ip_part=$(echo "$line" | cut -d: -f2 | tr -d '[:space:]')
                [[ "$iface_name" == "lo" ]] || [[ "$iface_name" == "lo:"* ]] && continue
                if [ -n "$ip_part" ] && validate_ip "$ip_part"; then
                    if [[ "$ip_part" =~ ^10\. ]] || [[ "$ip_part" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$ip_part" =~ ^192\.168\. ]]; then
                        detected_ip="$ip_part"
                        break
                    fi
                fi
            done <<< "$all_ips"
        fi
    fi
    
    echo "Device connected. Enabling TCP/IP mode..."
    if [ -n "$usb_device_id" ]; then
        if adb -s "$usb_device_id" tcpip 5555; then
            echo -e "${GREEN}Done! You can disconnect USB now.${NC}"
            notify "normal" "Camera Setup" "✅ Fixed! Unplug USB." "smartphone"
        else
            echo -e "${RED}Error:${NC} Failed to enable TCP/IP mode"
            notify "critical" "Camera Setup" "Failed to enable TCP/IP" "error"
            return 1
        fi
    else
        if adb tcpip 5555; then
            echo -e "${GREEN}Done! You can disconnect USB now.${NC}"
            notify "normal" "Camera Setup" "✅ Fixed! Unplug USB." "smartphone"
        else
            echo -e "${RED}Error:${NC} Failed to enable TCP/IP mode"
            notify "critical" "Camera Setup" "Failed to enable TCP/IP" "error"
            return 1
        fi
    fi
    
    if [ -n "$detected_ip" ]; then
        if load_config 2>/dev/null; then
            if sed -i "s|PHONE_IP=.*|PHONE_IP=\"$detected_ip\"|" "$CONFIG_FILE" 2>/dev/null; then
                echo -e "${GREEN}Saved IP to config: $detected_ip${NC}"
            fi
        else
            mkdir -p "$CONFIG_DIR"
            printf '# Android Webcam Configuration\nPHONE_IP="%s"\nCAMERA_FACING="back"\nVIDEO_SIZE=""\nBIT_RATE="8M"\nEXTRA_ARGS="--no-audio --v4l2-buffer=400"\nSHOW_WINDOW="true"\nRELOAD_V4L2_ON_STOP="true"\n' "$detected_ip" > "$CONFIG_FILE" 2>/dev/null && \
                echo -e "${GREEN}Saved IP to config: $detected_ip${NC}"
        fi
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
            if command -v head >/dev/null 2>&1; then
                PID=$(pgrep -f "scrcpy.*video-source=camera" | head -n 1)
            else
                PID=$(pgrep -f "scrcpy.*video-source=camera" | sed -n '1p')
            fi
        elif command -v ps >/dev/null 2>&1 && command -v awk >/dev/null 2>&1; then
            if command -v head >/dev/null 2>&1; then
                PID=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | awk '{print $2}' | head -n 1)
            else
                PID=$(ps aux 2>/dev/null | grep "[s]crcpy.*video-source=camera" | awk '{print $2}' | sed -n '1p')
            fi
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
    "$editor" "$CONFIG_FILE"
}

cmd_uninstall() {
    echo -e "${RED}!!! WARNING !!!${NC}"
    echo "This will remove configuration files, icons, and control scripts."
    read -r -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} sudo is required to uninstall."
        return 1
    fi
    if ! sudo -v 2>/dev/null; then
        echo -e "${RED}Error:${NC} Could not obtain sudo privileges."
        return 1
    fi

    echo -e "${BLUE}[INFO]${NC} Removing files..."
    sudo rm -f /usr/local/bin/android-webcam-ctl
    sudo rm -f /usr/local/bin/android-webcam-common
    sudo rm -f /usr/local/bin/android-webcam-run-in-terminal
    rm -f "$HOME/.local/bin/android-webcam-ctl"
    rm -f "$HOME/.local/bin/android-cam-toggle.sh"
    rm -f "$HOME/.local/bin/android-cam-fix.sh"
    rm -rf "$HOME/.config/android-webcam"
    rm -f "$HOME/.local/share/applications/android-cam.desktop"
    rm -f "$HOME/.local/share/applications/android-cam-fix.desktop"

    echo -e "${GREEN}[OK]${NC} Files removed."

    if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "^scrcpy "; then
        echo "scrcpy is installed via Snap."
        read -r -p "Remove scrcpy (Snap)? (y/N): " snap_confirm
        if [[ "$snap_confirm" == "y" || "$snap_confirm" == "Y" ]]; then
            sudo snap remove scrcpy 2>/dev/null || true
        fi
    fi
    if command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
        echo "scrcpy is installed via Flatpak."
        read -r -p "Remove scrcpy (Flatpak)? (y/N): " fp_confirm
        if [[ "$fp_confirm" == "y" || "$fp_confirm" == "Y" ]]; then
            flatpak uninstall -y org.scrcpy.ScrCpy 2>/dev/null || true
        fi
    fi

    read -r -p "Remove system dependencies (scrcpy, v4l2loopback, xvfb etc.)? (y/N): " pkg_confirm
    if [[ "$pkg_confirm" == "y" || "$pkg_confirm" == "Y" ]]; then
        local distro="unknown"
        [ -f /etc/os-release ] && . /etc/os-release && distro="${ID:-unknown}"
        case "$distro" in
            ubuntu|debian|pop|linuxmint|zorin|kali|neon) sudo apt remove -y scrcpy v4l2loopback-dkms v4l2loopback-utils xvfb ;;
            arch|manjaro) sudo pacman -Rs scrcpy v4l2loopback-dkms xorg-server-xvfb ;;
            fedora) sudo dnf remove -y scrcpy v4l2loopback v4l2loopback-utils xorg-x11-server-Xvfb ;;
            opensuse*|suse) sudo zypper remove -y scrcpy v4l2loopback-kmp-default v4l2loopback-utils xorg-x11-server-extra ;;
            *) echo "Please remove packages manually for your distro." ;;
        esac
    fi

    echo -e "${GREEN}[OK]${NC} Uninstallation completed."
    exit 0
}

# --- Main ---

case "$1" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    toggle)  cmd_toggle ;;
    setup)   cmd_fix ;;
    fix)     cmd_fix ;;  # backward compatibility
    status)  cmd_status ;;
    config)  cmd_config ;;
    uninstall) cmd_uninstall ;;
    *)
        echo "Usage: $0 {start|stop|toggle|setup|status|config|uninstall}"
        exit 1
        ;;
esac
EOF

if ! sudo install -m 0755 "$TMP_CTL" "$BIN_DIR/android-webcam-ctl"; then
    log_error "Failed to install android-webcam-ctl to $BIN_DIR!"
    exit 1
fi

# Generate Config
CONFIG_DIR="$HOME/.config/android-webcam"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
mkdir -p "$CONFIG_DIR"

# Only create if doesn't exist to respect user edits on re-install
if [ ! -f "$CONFIG_FILE" ]; then
    log_info "Creating initial configuration..."
    printf '# Android Webcam Configuration\nPHONE_IP=""\nCAMERA_FACING="back"\nVIDEO_SIZE=""\nBIT_RATE="8M"\nEXTRA_ARGS="--no-audio --v4l2-buffer=400"  # Additional scrcpy arguments\nSHOW_WINDOW="true"\nRELOAD_V4L2_ON_STOP="true"\n' > "$CONFIG_FILE"
fi

# --- STEP 4: ICONS ---
echo -e "\n${GREEN}[4/4] Creating Launcher Icons...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

cat << EOF > "$APP_DIR/android-cam.desktop"
[Desktop Entry]
Version=1.0
Name=Camera Phone
Comment=Toggle Android Camera
Exec=/usr/local/bin/android-webcam-ctl toggle
Path=/usr/local/bin
Icon=camera-web
Terminal=false
Type=Application
Categories=Utility;Video;
StartupWMClass=scrcpy
Actions=Status;Config;Setup;Stop;

[Desktop Action Status]
Name=Check Status
Exec=/usr/local/bin/android-webcam-run-in-terminal status
Path=/usr/local/bin
Terminal=false

[Desktop Action Config]
Name=Settings
Exec=/usr/local/bin/android-webcam-run-in-terminal config
Path=/usr/local/bin
Terminal=false

[Desktop Action Setup]
Name=Setup (fix)
Exec=/usr/local/bin/android-webcam-run-in-terminal setup
Path=/usr/local/bin
Terminal=false

[Desktop Action Stop]
Name=Stop Camera
Exec=/usr/local/bin/android-webcam-ctl stop
Path=/usr/local/bin
Terminal=false
EOF

# Separate Setup (fix) Icon (Optional but useful)
cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Setup (fix)
Comment=Reconnect after restart
Exec=/usr/local/bin/android-webcam-run-in-terminal setup
Icon=smartphone
Terminal=false
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
echo "What's next:"
echo "1. To pair your phone and set IP: run 'android-webcam-ctl setup' or use the 'Setup (fix)' icon in the app menu. Connect USB when prompted, then disconnect."
echo "2. Use the 'Camera Phone' icon to toggle the webcam."
echo "3. Run 'android-webcam-ctl config' to change settings."
echo ""
echo -e "${YELLOW}Did I save you some time? A virtual coffee is a great way to say thanks!${NC}"
echo -e "${BLUE}☕ https://buycoffee.to/kacoze ${NC}"
echo ""
