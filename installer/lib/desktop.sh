#!/usr/bin/env bash

install_desktop_entries() {
  local desktop_dir="$HOME/.local/share/applications"
  mkdir -p "$desktop_dir"

  cat > "$desktop_dir/android-cam.desktop" <<'EOF'
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
Actions=Status;Config;Setup;Stop;Logs;Update;

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

[Desktop Action Logs]
Name=Show Logs
Exec=/usr/local/bin/android-webcam-run-in-terminal logs
Path=/usr/local/bin
Terminal=false

[Desktop Action Update]
Name=Update
Exec=/usr/local/bin/android-webcam-run-in-terminal update
Path=/usr/local/bin
Terminal=false
EOF

  cat > "$desktop_dir/android-cam-fix.desktop" <<'EOF'
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

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  fi
}

remove_desktop_entries() {
  rm -f "$HOME/.local/share/applications/android-cam.desktop"
  rm -f "$HOME/.local/share/applications/android-cam-fix.desktop"
}
