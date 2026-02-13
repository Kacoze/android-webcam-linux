#!/usr/bin/env bash
set -euo pipefail

AUTO_YES=false
WANTS_HELP=false
CHECK_ONLY=false
DO_UNINSTALL=false
UNKNOWN_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    --help|-h) WANTS_HELP=true ;;
    --check-only) CHECK_ONLY=true ;;
    --uninstall|-u) DO_UNINSTALL=true ;;
    *) UNKNOWN_ARGS+=("$arg") ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# If invoked from wrapper download directory, library path is sibling.
if [ ! -d "$LIB_DIR" ] && [ -d "$ROOT_DIR/installer/lib" ]; then
  LIB_DIR="$ROOT_DIR/installer/lib"
fi

# shellcheck disable=SC1091
source "$LIB_DIR/logging.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/prompt.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/system.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/deps.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/assets.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/desktop.sh"

SCRIPT_VERSION="${ANDROID_WEBCAM_VERSION:-}"
if [ -f "$ROOT_DIR/VERSION" ]; then
  SCRIPT_VERSION="$(sed -n '1p' "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
fi
if [ -z "$SCRIPT_VERSION" ]; then
  SCRIPT_VERSION="dev"
fi

BIN_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/android-webcam"
CONFIG_FILE="$CONFIG_DIR/settings.conf"

show_help() {
  print_banner
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
  --yes, -y         Non-interactive mode (auto-confirm prompts)
  --check-only      Run preflight checks and exit
  --uninstall, -u   Remove installed files and desktop entries
  --help, -h        Show this help
EOF
}

write_default_config() {
  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<'EOF'
# Android Webcam Configuration
PHONE_IP=""
CAMERA_FACING="back"
VIDEO_SIZE=""
BIT_RATE="8M"
EXTRA_ARGS="--no-audio --v4l2-buffer=400"
SHOW_WINDOW="true"
RELOAD_V4L2_ON_STOP="true"
V4L2_SINK="/dev/video10"
EOF
    log_success "Created default config: $CONFIG_FILE"
  else
    log_info "Config exists, keeping current file: $CONFIG_FILE"
  fi
}

run_check_only() {
  print_banner
  local distro
  distro=$(detect_distro)
  log_info "Distro: $distro"
  if command -v sudo >/dev/null 2>&1 || [ "$EUID" -eq 0 ]; then
    log_success "Privilege escalation available"
  else
    log_error "sudo missing and not root"
    return 1
  fi
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    log_success "Downloader available"
  else
    log_error "Missing curl/wget"
    return 1
  fi
  if command -v bash >/dev/null 2>&1; then
    log_success "bash available"
  else
    log_error "bash missing"
    return 1
  fi
  return 0
}

do_uninstall() {
  echo -e "${RED}!!! WARNING !!!${NC}"
  echo "This will remove scripts, desktop entries, and config."
  prompt_read "Are you sure? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi

  check_sudo
  sudo rm -f /usr/local/bin/android-webcam-ctl /usr/local/bin/android-webcam-common /usr/local/bin/android-webcam-run-in-terminal
  sudo rm -f /usr/bin/android-webcam-ctl /usr/bin/android-webcam-common /usr/bin/android-webcam-run-in-terminal
  sudo rm -rf /usr/local/share/android-webcam /usr/share/android-webcam
  remove_desktop_entries
  rm -rf "$CONFIG_DIR"
  log_success "Uninstall complete"
}

install_runtime_scripts() {
  local tmp
  local rc=0
  tmp="$(mktemp -d)"

  resolve_source_files "$ROOT_DIR" "$tmp" || rc=$?
  if [ "$rc" -eq 0 ]; then
    check_sudo || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    sudo install -m 0755 "$tmp/android-webcam-ctl" "$BIN_DIR/android-webcam-ctl" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    sudo install -m 0644 "$tmp/android-webcam-common" "$BIN_DIR/android-webcam-common" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    sudo install -m 0755 "$tmp/android-webcam-run-in-terminal" "$BIN_DIR/android-webcam-run-in-terminal" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    sudo mkdir -p /usr/local/share/android-webcam || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    printf "%s\n" "$SCRIPT_VERSION" | sudo tee /usr/local/share/android-webcam/VERSION >/dev/null || rc=$?
  fi

  rm -rf "$tmp"
  return "$rc"
}

main() {
  setup_prompt_fd

  if [ "$WANTS_HELP" = true ]; then
    show_help
    exit 0
  fi

  if [ "${#UNKNOWN_ARGS[@]}" -gt 0 ]; then
    log_error "Unknown option(s): ${UNKNOWN_ARGS[*]}"
    show_help
    exit 1
  fi

  if [ "$DO_UNINSTALL" = true ]; then
    do_uninstall
    exit 0
  fi

  if [ "$CHECK_ONLY" = true ]; then
    run_check_only
    exit $?
  fi

  print_banner
  check_sudo
  check_internet
  check_video_group

  local distro
  distro=$(detect_distro)
  log_info "Detected distro: $distro"

  log_info "Installing dependencies..."
  install_deps "$distro"

  log_info "Installing runtime scripts..."
  install_runtime_scripts

  log_info "Configuring v4l2loopback..."
  ensure_v4l2_conf

  log_info "Installing desktop entries..."
  install_desktop_entries

  write_default_config

  log_success "Installation complete."
  echo "Next steps:"
  echo "1) android-webcam-ctl setup"
  echo "2) android-webcam-ctl start"
  echo "3) android-webcam-ctl doctor"
}

main "$@"
