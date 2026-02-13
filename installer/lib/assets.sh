#!/usr/bin/env bash

have() { command -v "$1" >/dev/null 2>&1; }

download_file() {
  local url="$1"
  local out="$2"
  if have curl; then
    curl -fsSL "$url" -o "$out"
  elif have wget; then
    wget -qO "$out" "$url"
  else
    log_error "curl or wget required"
    return 1
  fi
}

resolve_source_files() {
  local script_dir="$1"
  local out_dir="$2"
  mkdir -p "$out_dir"

  # Local repo path (preferred)
  if [ -f "$script_dir/src/android-webcam-ctl" ] && [ -f "$script_dir/src/android-webcam-common" ]; then
    cp -f "$script_dir/src/android-webcam-ctl" "$out_dir/android-webcam-ctl"
    cp -f "$script_dir/src/android-webcam-common" "$out_dir/android-webcam-common"
    cp -f "$script_dir/src/android-webcam-run-in-terminal" "$out_dir/android-webcam-run-in-terminal"
    chmod 0755 "$out_dir/android-webcam-ctl" "$out_dir/android-webcam-run-in-terminal"
    chmod 0644 "$out_dir/android-webcam-common"
    return 0
  fi

  local repo="${ANDROID_WEBCAM_REPO:-Kacoze/android-webcam-linux}"
  local ref="${ANDROID_WEBCAM_REF:-main}"
  local raw="https://raw.githubusercontent.com/${repo}/${ref}/src"

  log_info "Downloading runtime scripts from ${repo}@${ref}"
  download_file "$raw/android-webcam-ctl" "$out_dir/android-webcam-ctl"
  download_file "$raw/android-webcam-common" "$out_dir/android-webcam-common"
  download_file "$raw/android-webcam-run-in-terminal" "$out_dir/android-webcam-run-in-terminal"
  chmod 0755 "$out_dir/android-webcam-ctl" "$out_dir/android-webcam-run-in-terminal"
  chmod 0644 "$out_dir/android-webcam-common"
}
