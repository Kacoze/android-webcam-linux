#!/usr/bin/env bash
set -euo pipefail

section() { printf "\n== %s ==\n" "$1"; }
kv() { printf "%-22s %s\n" "$1" "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }

get_os_id() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf "%s" "${ID:-unknown}"
  else
    printf "unknown"
  fi
}

get_scrcpy_ver() {
  local cmd="$1"
  local out=""
  # cmd may be a path or a "flatpak run ..." command
  if [[ "$cmd" == "flatpak run "* ]]; then
    out=$(flatpak run org.scrcpy.ScrCpy --version 2>/dev/null || true)
  else
    out=$("$cmd" --version 2>/dev/null || true)
  fi
  printf "%s" "$(printf "%s" "$out" | sed -n 's/.*scrcpy[[:space:]]*\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?\).*/\1/p' | sed -n '1p')"
}

section "System"
kv "os_id" "$(get_os_id)"
kv "kernel" "$(uname -r)"
kv "arch" "$(uname -m)"
kv "session_type" "${XDG_SESSION_TYPE:-unknown}"
kv "wayland_display" "${WAYLAND_DISPLAY:-}"
kv "display" "${DISPLAY:-}"

section "Key dependencies"
kv "adb" "$(have adb && command -v adb || echo 'missing')"
kv "ffmpeg" "$(have ffmpeg && command -v ffmpeg || echo 'missing')"
kv "notify-send" "$(have notify-send && command -v notify-send || echo 'missing')"
kv "xvfb-run" "$(have xvfb-run && command -v xvfb-run || echo 'missing (needed for SHOW_WINDOW=false)')"

section "scrcpy candidates"
declare -a candidates=()
[ -x "$HOME/.local/bin/scrcpy" ] && candidates+=("$HOME/.local/bin/scrcpy")
[ -x /snap/bin/scrcpy ] && candidates+=("/snap/bin/scrcpy")
have scrcpy && candidates+=("$(command -v scrcpy)")
if have flatpak && flatpak list --app 2>/dev/null | grep -q org.scrcpy.ScrCpy; then
  candidates+=("flatpak run org.scrcpy.ScrCpy")
fi

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "No scrcpy installation detected."
else
  for c in "${candidates[@]}"; do
    v="$(get_scrcpy_ver "$c")"
    [ -z "$v" ] && v="unknown"
    kv "scrcpy" "$c (version: $v)"
  done
fi

section "scrcpy server payload (important for GitHub installs)"
if [ -x "$HOME/.local/bin/scrcpy" ]; then
  if [ -f "$HOME/.local/bin/scrcpy-server" ]; then
    kv "server" "$HOME/.local/bin/scrcpy-server (OK)"
  elif [ -f "$HOME/.local/bin/scrcpy-server.jar" ]; then
    kv "server" "$HOME/.local/bin/scrcpy-server.jar (OK)"
  else
    kv "server" "missing next to ~/.local/bin/scrcpy (LIKELY BROKEN)"
    echo "Hint: if you installed scrcpy manually, ensure 'scrcpy-server' is installed next to the scrcpy binary (or use Snap/Flatpak/system package)."
  fi
else
  echo "GitHub-style scrcpy in ~/.local/bin not detected; skipping payload check."
fi

section "v4l2loopback / virtual camera"
if [ -c /dev/video10 ]; then
  kv "/dev/video10" "present"
else
  kv "/dev/video10" "missing"
fi

if have lsmod; then
  if lsmod 2>/dev/null | grep -q '^v4l2loopback'; then
    kv "module" "loaded"
  else
    kv "module" "not loaded"
  fi
else
  kv "lsmod" "missing (cannot check module state)"
fi

if [ -f /etc/modprobe.d/v4l2loopback.conf ]; then
  kv "modprobe_conf" "/etc/modprobe.d/v4l2loopback.conf exists"
  sed -n '1,5p' /etc/modprobe.d/v4l2loopback.conf 2>/dev/null || true
else
  kv "modprobe_conf" "missing"
fi

section "Secure Boot (best-effort)"
if have mokutil; then
  mokutil --sb-state 2>/dev/null || true
else
  echo "mokutil not installed (cannot check Secure Boot state)."
fi

section "Desktop entries (after install)"
kv "camera_desktop" "$HOME/.local/share/applications/android-cam.desktop"
kv "setup_desktop" "$HOME/.local/share/applications/android-cam-fix.desktop"

echo
echo "Done. If something is missing, fix dependencies/module first, then re-run the installer and re-run this script."

