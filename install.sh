#!/bin/bash

# Kolory dla lepszego UX
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Android Webcam Setup (Linux)          ${NC}"
echo -e "${BLUE}=========================================${NC}"

# KROK 1: Zależności
echo -e "\n${GREEN}[1/5] Instalacja zależności systemowych...${NC}"
DEPENDENCIES="android-tools-adb v4l2loopback-dkms v4l2loopback-utils scrcpy ffmpeg"

# Aktualizacja i instalacja (apt sam pominie zainstalowane)
if ! sudo apt update && sudo apt install -y $DEPENDENCIES; then
    echo -e "${RED}Błąd instalacji pakietów! Sprawdź połączenie z internetem.${NC}"
    exit 1
fi

# KROK 2: Konfiguracja modułu wideo (v4l2loopback)
echo -e "\n${GREEN}[2/5] Konfiguracja wirtualnej kamery...${NC}"
CONF_FILE="/etc/modprobe.d/v4l2loopback.conf"
LOAD_FILE="/etc/modules-load.d/v4l2loopback.conf"

# Sprawdzamy czy konfiguracja już istnieje, jeśli nie - tworzymy
if ! grep -q "Android Cam" "$CONF_FILE" 2>/dev/null; then
    echo "Tworzenie konfiguracji sterownika..."
    echo "options v4l2loopback video_nr=10 card_label=\"Android Cam\" exclusive_caps=1" | sudo tee "$CONF_FILE" > /dev/null
    echo "v4l2loopback" | sudo tee "$LOAD_FILE" > /dev/null
    
    # Przeładowanie modułu
    sudo modprobe -r v4l2loopback 2>/dev/null
    sudo modprobe v4l2loopback
    echo "Moduł załadowany pomyślnie."
else
    echo "Sterownik jest już skonfigurowany."
fi

# KROK 3: Wykrywanie telefonu i IP
echo -e "\n${GREEN}[3/5] Parowanie telefonu...${NC}"
echo "---------------------------------------------------"
echo "PROSZĘ WYKONAĆ TERAZ:"
echo "1. Podłącz telefon kablem USB do komputera."
echo "2. Upewnij się, że debugowanie USB jest włączone."
echo "3. Zaakceptuj klucz RSA na ekranie telefonu (jeśli zapyta)."
echo "---------------------------------------------------"
echo "Oczekiwanie na urządzenie..."

adb wait-for-usb-device

echo "Wykryto urządzenie! Pobieranie adresu IP..."
# Próba automatycznego wyciągnięcia IP z interfejsu wlan0
PHONE_IP=$(adb shell ip -4 -o addr show wlan0 | awk '{print $4}' | cut -d/ -f1)

if [ -z "$PHONE_IP" ]; then
    echo -e "${RED}Nie udało się wykryć IP automatycznie.${NC}"
    echo "Upewnij się, że telefon jest połączony z Wi-Fi."
    read -p "Podaj adres IP telefonu ręcznie (np. 192.168.1.XX): " PHONE_IP
else
    echo -e "Znaleziono IP: ${BLUE}$PHONE_IP${NC}"
fi

# Zapis konfiguracji
CONFIG_DIR="$HOME/.config/android-webcam"
mkdir -p "$CONFIG_DIR"
echo "PHONE_IP=$PHONE_IP:5555" > "$CONFIG_DIR/config.env"

# Przełączenie ADB w tryb TCP
echo "Przełączanie ADB w tryb sieciowy (port 5555)..."
adb tcpip 5555
sleep 3
echo "Gotowe."

# KROK 4: Generowanie skryptów sterujących
echo -e "\n${GREEN}[4/5] Instalowanie skryptów sterujących...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# -- Skrypt TOGGLE (Włącz/Wyłącz) --
cat << 'EOF' > "$BIN_DIR/android-cam-toggle.sh"
#!/bin/bash
source ~/.config/android-webcam/config.env
LOG="/tmp/android-cam.log"

# Jeśli działa -> Wyłącz
if pgrep -f "scrcpy.*video-source=camera" > /dev/null; then
    pkill -f "scrcpy.*video-source=camera"
    notify-send -u low -i camera-web "Kamera Android" "Zatrzymano przesyłanie."
    exit 0
fi

# Jeśli nie działa -> Włącz
notify-send -u low -i camera-web "Kamera Android" "Łączenie z $PHONE_IP..."

# Próba połączenia
adb connect $PHONE_IP > /dev/null
# Nawet jeśli adb connect zwróci błąd, scrcpy czasem potrafi się połączyć, więc próbujemy odpalić:

nohup scrcpy -s $PHONE_IP --video-source=camera --camera-facing=front --v4l2-sink=/dev/video0 --no-audio > "$LOG" 2>&1 &
PID=$!

sleep 3
if ps -p $PID > /dev/null; then
    notify-send -u normal -i camera-web "Kamera Android" "Działa! (PID: $PID)"
else
    # Czytamy błąd
    ERR=$(head -n 5 "$LOG")
    notify-send -u critical -i error "Błąd Kamery" "Nie udało się uruchomić.\nUżyj opcji 'Napraw Kamerę (USB)'."
fi
EOF

# -- Skrypt FIX (Naprawa po restarcie telefonu) --
cat << 'EOF' > "$BIN_DIR/android-cam-fix.sh"
#!/bin/bash
notify-send -i smartphone "Kamera Setup" "Podłącz telefon kablem USB..."
adb wait-for-usb-device
adb tcpip 5555
notify-send -i smartphone "Kamera Setup" "Gotowe! Możesz odłączyć kabel."
EOF

chmod +x "$BIN_DIR/android-cam-toggle.sh"
chmod +x "$BIN_DIR/android-cam-fix.sh"

# KROK 5: Generowanie ikon w menu
echo -e "\n${GREEN}[5/5] Tworzenie skrótów w menu...${NC}"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

# Ikona Główna
cat << EOF > "$APP_DIR/android-cam.desktop"
[Desktop Entry]
Version=1.0
Name=Kamera Telefon
Comment=Włącz/Wyłącz kamerę z Androida
Exec=$BIN_DIR/android-cam-toggle.sh
Icon=camera-web
Terminal=false
Type=Application
Categories=Utility;Video;
EOF

# Ikona Naprawcza
cat << EOF > "$APP_DIR/android-cam-fix.desktop"
[Desktop Entry]
Version=1.0
Name=Napraw Kamerę (USB)
Comment=Kliknij, jeśli zrestartowałeś telefon
Exec=$BIN_DIR/android-cam-fix.sh
Icon=smartphone
Terminal=false
Type=Application
Categories=Utility;Settings;
EOF

# Odświeżenie bazy ikon (dla pewności)
update-desktop-database "$APP_DIR" 2>/dev/null

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}   INSTALACJA ZAKOŃCZONA SUKCESEM!       ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "Możesz bezpiecznie odłączyć kabel USB."
echo "W menu aplikacji znajdziesz teraz:"
echo " 1. Kamera Telefon (używaj na co dzień)"
echo " 2. Napraw Kamerę (używaj po restarcie telefonu)"
echo ""