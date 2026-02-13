#!/usr/bin/env bash

install_deps() {
  local distro="$1"
  case "$distro" in
    ubuntu|debian)
      sudo apt update
      sudo apt install -y adb scrcpy ffmpeg v4l2loopback-dkms v4l2loopback-utils curl wget libnotify-bin xvfb
      ;;
    fedora)
      sudo dnf install -y android-tools scrcpy ffmpeg v4l2loopback v4l2loopback-utils curl wget libnotify xorg-x11-server-Xvfb
      ;;
    arch)
      sudo pacman -Sy --noconfirm android-tools scrcpy ffmpeg v4l2loopback-dkms v4l2loopback-utils curl wget libnotify xorg-server-xvfb
      ;;
    opensuse*|opensuse-leap|sles|suse)
      sudo zypper --non-interactive refresh
      sudo zypper --non-interactive install android-tools scrcpy ffmpeg v4l2loopback-kmp-default v4l2loopback-utils curl wget libnotify-tools xorg-x11-server-extra
      ;;
    *)
      log_warn "Unsupported distro: $distro"
      log_warn "Install manually: adb, scrcpy>=2.0, ffmpeg, v4l2loopback, libnotify, xvfb"
      ;;
  esac
}
