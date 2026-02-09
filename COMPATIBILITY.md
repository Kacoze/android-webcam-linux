# Compatibility / Support Policy

This project can work on **many** Linux distributions, but it cannot be guaranteed to work on **all** distributions.
Linux differs by kernel configuration, Secure Boot policy, packaging, immutability (OSTree), containerization, etc.

This document defines what is **supported**, what is **expected to work**, and what is **out of scope**.

---

## What “works” means here

The solution is considered working when:

- `v4l2loopback` provides a stable virtual camera device (default: `/dev/video10` labeled **Android Cam**)
- `adb` can connect to the phone over Wi‑Fi (`PHONE_IP:5555`)
- `scrcpy >= 2.0` can run `--video-source=camera` (Android **12+**) and stream into the V4L2 sink
- Video apps (OBS/Zoom/Meet/Teams/browsers) can open `/dev/video10`

---

## Target scope (what we actively support)

### Supported by the installer (automatic dependency install)

The installer currently has explicit support for these families (via their package managers):

- **Debian/Ubuntu family**: `ubuntu`, `debian`, `pop`, `linuxmint`, `kali`, `neon`, `zorin`
- **Arch family**: `arch`, `manjaro`, `endeavouros`, `garuda`
- **Fedora family**: `fedora`, `nobara`, and best-effort for `rhel`, `centos` (repo availability varies)
- **openSUSE family**: `opensuse*`, `suse`

If your distro ID is not in the list, installation is **manual** (see “Out of scope / manual-only”).

### Supported host architectures

Best-effort support for:

- `x86_64`
- `arm64` / `aarch64`
- `armv7`

Other architectures are not covered by the GitHub download fallback for `scrcpy`.

### Supported modes

- **Desktop (X11 or Wayland)**: supported
- **Headless** (no visible preview window): supported via `SHOW_WINDOW=false` and `xvfb-run`

---

## Compatibility matrix (high-level)

Legend:

- ✅ = expected to work with the installer and default settings
- ⚠️ = likely works, but common distro-specific hurdle(s)
- ❌ = not supported / won’t work without major changes

| Distro / Environment | Installer deps | `v4l2loopback` availability | Common blockers / notes |
|---|---:|---:|---|
| Ubuntu / Debian family | ✅ | ✅ (DKMS) | ⚠️ Secure Boot may block DKMS module; `scrcpy` from APT is often **too old**, installer uses Snap/Flatpak/GitHub |
| Arch family | ✅ | ✅ (DKMS) | ⚠️ Ensure kernel headers match running kernel (DKMS) |
| Fedora family | ✅ | ⚠️ | ⚠️ Often requires **RPMFusion** for `v4l2loopback`; SELinux is usually fine but custom hardening can interfere |
| openSUSE | ✅ | ✅ (KMP) | ⚠️ Kernel flavor must match KMP package (`default`, etc.) |
| Immutable/OSTree (Silverblue, etc.) | ⚠️ | ⚠️ | ⚠️ Writing to `/usr/local` and DKMS are not a great fit; use toolbox/layering or distro-native approach |
| NixOS / Guix | ❌ | ⚠️ | ❌ Installer is not designed for declarative systems; manual packaging needed |
| Alpine (musl) | ❌ | ⚠️ | ❌ `scrcpy` releases are glibc-based; packaging differs; manual build required |
| Containers (Docker/LXC) | ❌ | ❌ | ❌ No kernel module loading; `/dev/video*` and `adb` device access is non-trivial |
| WSL | ❌ | ❌ | ❌ No Linux kernel modules and no real V4L2 device nodes |

---

## Known “universal Linux” pitfalls

### Secure Boot

If Secure Boot is enabled, loading unsigned `v4l2loopback` often fails (`Required key not available`).
You must **disable Secure Boot** or **sign the module** (MOK).

### DKMS and kernel headers

On DKMS-based distros, you need kernel headers/build tools for the **running** kernel.

### `scrcpy` from GitHub Releases

The official `scrcpy` Linux release archives include an additional server payload (e.g. `scrcpy-server`).
Installing only the `scrcpy` binary may break runtime if the server file is missing.

This repository’s installer is expected to install both the client and the server when using the GitHub fallback.

### Firewalls / network policy

Wireless ADB uses TCP port **5555** inside your LAN.
Local firewall rules, guest Wi‑Fi isolation, or VLAN separation can break it.

---

## Manual-only / Out of scope

We do not currently provide an automated installer path for:

- distros without APT/Pacman/DNF/Zypper
- systems without `sudo`
- hardened systems where loading kernel modules is forbidden by policy

If you want first-class support for a missing distro family, contributions are welcome:
please include a tested package list and any special handling notes.
