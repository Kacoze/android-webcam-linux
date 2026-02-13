#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper for modular installer implementation.
# Local repo usage: executes installer/main.sh.
# Standalone usage (downloaded install.sh): downloads installer modules from GitHub.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_MAIN="$SCRIPT_DIR/installer/main.sh"

if [ -f "$LOCAL_MAIN" ]; then
  exec bash "$LOCAL_MAIN" "$@"
fi

have() { command -v "$1" >/dev/null 2>&1; }

download_file() {
  local url="$1"
  local out="$2"
  if have curl; then
    curl -fsSL "$url" -o "$out"
  elif have wget; then
    wget -qO "$out" "$url"
  else
    echo "Error: curl or wget is required." >&2
    exit 1
  fi
}

REPO="${ANDROID_WEBCAM_REPO:-Kacoze/android-webcam-linux}"
REF="${ANDROID_WEBCAM_REF:-main}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/installer/lib"

raw_base="https://raw.githubusercontent.com/${REPO}/${REF}/installer"

download_installer_modules() {
  local ok=false
  if [[ "$REF" == v* ]]; then
    local rel="https://github.com/${REPO}/releases/download/${REF}"
    if download_file "$rel/main.sh" "$tmp_dir/installer/main.sh" 2>/dev/null \
      && download_file "$rel/logging.sh" "$tmp_dir/installer/lib/logging.sh" 2>/dev/null \
      && download_file "$rel/prompt.sh" "$tmp_dir/installer/lib/prompt.sh" 2>/dev/null \
      && download_file "$rel/system.sh" "$tmp_dir/installer/lib/system.sh" 2>/dev/null \
      && download_file "$rel/deps.sh" "$tmp_dir/installer/lib/deps.sh" 2>/dev/null \
      && download_file "$rel/assets.sh" "$tmp_dir/installer/lib/assets.sh" 2>/dev/null \
      && download_file "$rel/desktop.sh" "$tmp_dir/installer/lib/desktop.sh" 2>/dev/null; then
      ok=true
    fi
  fi
  if [ "$ok" = false ]; then
    download_file "$raw_base/main.sh" "$tmp_dir/installer/main.sh"
    download_file "$raw_base/lib/logging.sh" "$tmp_dir/installer/lib/logging.sh"
    download_file "$raw_base/lib/prompt.sh" "$tmp_dir/installer/lib/prompt.sh"
    download_file "$raw_base/lib/system.sh" "$tmp_dir/installer/lib/system.sh"
    download_file "$raw_base/lib/deps.sh" "$tmp_dir/installer/lib/deps.sh"
    download_file "$raw_base/lib/assets.sh" "$tmp_dir/installer/lib/assets.sh"
    download_file "$raw_base/lib/desktop.sh" "$tmp_dir/installer/lib/desktop.sh"
  fi
}

download_installer_modules

chmod 0755 "$tmp_dir/installer/main.sh"

if [[ "$REF" == v* ]] && [ -z "${ANDROID_WEBCAM_VERSION:-}" ]; then
  export ANDROID_WEBCAM_VERSION="${REF#v}"
fi

exec bash "$tmp_dir/installer/main.sh" "$@"
