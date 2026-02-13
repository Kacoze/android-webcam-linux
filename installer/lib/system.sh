#!/usr/bin/env bash

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

check_sudo() {
  if [ "$EUID" -eq 0 ]; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo not found and not running as root."
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    log_info "Administrator privileges are required."
    sudo -v || { log_error "Failed to obtain sudo privileges."; exit 1; }
  fi
}

check_internet() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 5 https://www.google.com >/dev/null 2>&1 || {
      log_error "No internet connection detected."
      exit 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO - --timeout=5 https://www.google.com >/dev/null 2>&1 || {
      log_error "No internet connection detected."
      exit 1
    }
  else
    log_warn "Cannot verify internet (missing curl/wget)."
  fi
}

check_video_group() {
  if command -v id >/dev/null 2>&1 && ! id -nG 2>/dev/null | grep -q '\bvideo\b'; then
    log_warn "User '$USER' is not in 'video' group."
    log_warn "Run: sudo usermod -aG video $USER and re-login"
  fi
}

ensure_v4l2_conf() {
  local conf="/etc/modprobe.d/v4l2loopback.conf"
  if [ ! -f "$conf" ] || ! grep -q 'video_nr=10' "$conf" 2>/dev/null; then
    echo 'options v4l2loopback video_nr=10 card_label="Android Cam" exclusive_caps=1' | sudo tee "$conf" >/dev/null
    log_success "Configured v4l2loopback defaults in $conf"
  fi
}
