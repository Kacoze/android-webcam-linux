#!/bin/bash

# Colors for better UX
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Android Webcam Setup (Linux)          ${NC}"
echo -e "${BLUE}=========================================${NC}"

# STEP 1: Dependencies
echo -e "\n${GREEN}[1/5] Installing system dependencies...${NC}"
DEPENDENCIES="android-tools-adb v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg"

# Update and install (apt will skip already installed ones)
if ! sudo apt update && sudo apt install -y $DEPENDENCIES; then
    echo -e "${RED}Package installation failed! Check your internet connection.${NC}"
    exit 1
fi

# STEP 2: Video module configuration (v4l2loopback)
echo -e "\n${GREEN}[2/5] Configuring virtual camera...${NC}"
CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

# Check if configuration already exists, if not - create it
if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    echo "Creating driver configuration..."
    echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
    echo "v4l2loopback" | sudo tee "$LOAD_FILE" > /dev/null
    
    # Reload module
    sudo modprobe -r v4l2loopback 2>/dev/null
    sudo modprobe v4l2loopback
    echo "Module loaded successfully."
else
    echo "Driver is already configured."
fi

# STEP 3: Phone detection and IP
echo -e "\n${GREEN}[3/5] Pairing phone...${NC}"
echo "---------------------------------------------------"
echo "PLEASE DO THIS NOW:"
echo "1. Connect your phone to the computer via USB cable."
echo "2. Make sure USB Debugging is enabled."
echo "3. Accept the RSA key on your phone screen (if prompted)."
echo "---------------------------------------------------"
echo "Waiting for device..."

adb wait-for-usb-device

echo "Device detected! Fetching IP address..."
# Attempt to automatically extract IP from wlan0 interface
PHONE_IP=$(adb shell ip -4 -o addr show wlan0 | awk '{print $4}' | cut -d/ -f1)

if [ -z "$PHONE_IP" ]; then
    echo -e "${RED}Could not detect IP automatically.${NC}"
    echo "Make sure the phone is connected to Wi-Fi."
    read -p "Enter phone IP address manually (e.g., 192.168.1.XX): " PHONE_IP
else
    echo -e "Found IP: ${BLUE}$PHONE_IP${NC}"
fi

# Save configuration
CONFIG_DIR="$HOME/.config/android-webcam"
mkdir -p "$CONFIG_DIR"
echo "PHONE_IP=$PHONE_IP:5555" > "$CONFIG_DIR/config.env"

# Switch ADB to TCP mode
echo "Switching ADB to network mode (port 5555)..."
adb tcpip 5555
sleep 3
echo "Done."

# STEP 4: Generating control scripts
echo -e "\n${GREEN}[4/5] Installing control scripts...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# -- TOGGLE Script (On/Off) --
cat << 'EOF' > "$BIN_DIR/android-cam-toggle.sh"
#!/bin/bash
source ~/.config/android-webcam/config.env
LOG="/tmp/android-cam.log"

# If running -> Turn off
if pgrep -f "scrcpy.*video-source=camera" > /dev/null; then
    pkill -f "scrcpy.*video-source=camera"
    notify-send -u low -i camera-web "Android Camera" "Streaming stopped."
    exit 0
fi

# If not running -> Turn on
notify-send -u low -i camera-web "Android Camera" "Connecting to $PHONE_IP..."

# Attempt connection
adb connect $PHONE_IP > /dev/null
# Even if adb connect returns error, scrcpy might still connect, so try running:

nohup scrcpy -s $PHONE_IP --video-source=camera --camera-facing=front --v4l2-sink=/dev/video0 --no-audio > "$LOG" 2>&1 &
PID=$!

sleep 3
if ps -p $PID > /dev/null; then
    notify-send -u normal -i camera-web "Android Camera" "Active! (PID: $PID)"
else
    # Read error
    ERR=$(head -n 5 "$LOG")
    notify-send -u critical -i error "Camera Error" "Failed to start.\nUse 'Fix Camera (USB)' option."
fi
EOF

# -- FIX Script (Repair after phone restart) --
cat << 'EOF' > "$BIN_DIR/android-cam-fix.sh"
#!/bin/bash
notify-send -i smartphone "Camera Setup" "Connect phone via USB cable..."
adb wait-for-usb-device
adb tcpip 5555
notify-send -i smartphone "Camera Setup" "Done! You can disconnect the cable."
EOF

chmod +x "$BIN_DIR/android-cam-toggle.sh"
chmod +x "$BIN_DIR/android-cam-fix.sh"

# STEP 5: Generating menu icons
echo -e "\n${GREEN}[5/5] Creating menu shortcuts...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

# Main Icon
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

# Fix Icon
cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Fix Camera (USB)
Comment=Click if you restarted your phone
Exec=$BIN_DIR/android-cam-fix.sh
Icon=smartphone
Terminal=false
Type=Application
Categories=Utility;Settings;
EOF

# Refresh icon database (just in case)
update-desktop-database "$APP_DIR" 2>/dev/null

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}   INSTALLATION SUCCESSFUL!              ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "You can safely disconnect the USB cable."
echo "In your application menu you will now find:"
echo " 1. Camera Phone (daily usage)"
echo " 2. Fix Camera (use after phone restart)"
echo ""