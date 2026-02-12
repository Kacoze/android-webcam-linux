#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "Error: dpkg-deb not found. Install dpkg (Debian/Ubuntu) to build .deb." >&2
  exit 1
fi

tag_or_version="${1:-}"
if [ -z "$tag_or_version" ]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

version="$tag_or_version"
version="${version#v}"

pkg_name="android-webcam-linux"
arch="all"

out_dir="$REPO_ROOT/dist"
mkdir -p "$out_dir"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

root="$staging/root"
mkdir -p "$root/DEBIAN" "$root/usr/local/bin" "$root/usr/share/applications"

install -m 0755 "$REPO_ROOT/src/android-webcam-ctl" "$root/usr/local/bin/android-webcam-ctl"
install -m 0644 "$REPO_ROOT/src/android-webcam-common" "$root/usr/local/bin/android-webcam-common"
install -m 0755 "$REPO_ROOT/src/android-webcam-run-in-terminal" "$root/usr/local/bin/android-webcam-run-in-terminal"

cat > "$root/usr/share/applications/android-cam.desktop" <<'EOF'
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
Actions=Status;Config;Setup;Stop;Logs;

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
EOF

cat > "$root/usr/share/applications/android-cam-fix.desktop" <<'EOF'
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

cat > "$root/DEBIAN/control" <<EOF
Package: $pkg_name
Version: $version
Section: video
Priority: optional
Architecture: $arch
Maintainer: ${DEB_MAINTAINER:-Kacoze}
Homepage: https://github.com/Kacoze/android-webcam-linux
Depends: bash, curl | wget, android-tools-adb, scrcpy, v4l2loopback-dkms, v4l2loopback-utils, ffmpeg, libnotify-bin, xvfb
Description: Use Android phone as a Linux webcam via scrcpy + v4l2loopback
 Android webcam for Linux using adb + scrcpy camera source and v4l2loopback virtual device.
EOF

cat > "$root/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod 0755 "$root/DEBIAN/postinst"

deb_out="$out_dir/${pkg_name}_${version}_${arch}.deb"
dpkg-deb --build "$root" "$deb_out" >/dev/null

echo "$deb_out"
