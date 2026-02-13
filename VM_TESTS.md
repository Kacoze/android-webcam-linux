# VM smoke-test guide (Ubuntu/Debian/Fedora/Arch/openSUSE)

This repository cannot automatically guarantee “works on every Linux”, but we can **systematically validate** the most common targets in clean VMs.

The goal of the VM smoke tests is to prove:

- Dependencies can be installed (or the failure mode is clear)
- `v4l2loopback` can be loaded and `/dev/video10` is created
- `scrcpy >= 2.0` is available and has its **server payload**
- `android-webcam-ctl start/stop` works and leaves the system in a clean state

In addition to manual VM testing, the repository includes GitHub Actions workflows:

- `Integration Matrix (Manual)` (`.github/workflows/integration-matrix.yml`) for cross-distro container smoke checks.
- `VM Smoke (Manual)` (`.github/workflows/vm-smoke.yml`) for preflight reporting.

---

## Before you begin

- Use a clean VM snapshot for each distro.
- Enable networking.
- Make sure you can use `sudo`.
- For “wireless” testing, you still need the phone on the same LAN as the VM (NAT/bridged networking matters).

---

## Recommended VM matrix

Test these combinations where possible:

- **Ubuntu LTS**: Wayland + X11 (if available)
- **Debian stable**: X11 (Wayland optional)
- **Fedora**: Wayland + X11
- **Arch**: X11 or Wayland
- **openSUSE**: Wayland + X11

Security / kernel variants:

- Secure Boot **OFF** (baseline)
- Secure Boot **ON** (expect `v4l2loopback` issues unless signed)

---

## Test procedure (per VM)

### 1) Run preflight checks

Run:

```bash
./scripts/vm-smoke-test.sh
```

If it reports missing `adb` / `scrcpy` / `/dev/video10`, that’s expected before install.

### 2) Install the tool

From the repo root:

```bash
bash install.sh
```

If the VM distro is unsupported by the installer, install dependencies manually (see output) and repeat.

### 3) Run post-install smoke checks

Run again:

```bash
./scripts/vm-smoke-test.sh
```

Expected after install:

- `adb` present
- `scrcpy` present with version **>= 2.0**
- for GitHub-installed scrcpy: `~/.local/bin/scrcpy-server` exists next to `~/.local/bin/scrcpy`
- `v4l2loopback` can be loaded and `/dev/video10` exists

### 4) Validate start/stop behavior

1. Pair the phone (USB once):

```bash
android-webcam-ctl setup
```

2. Start camera:

```bash
android-webcam-ctl start
```

3. Confirm `/dev/video10` is readable by the user and appears in an app (OBS / browser camera selector).

4. Stop camera:

```bash
android-webcam-ctl stop
```

5. Start again (to catch the “Meet/Zoom does not see camera after restart” class of issues):

```bash
android-webcam-ctl start
android-webcam-ctl stop
```

---

## Fedora note: RPMFusion

On Fedora, `v4l2loopback` is commonly provided via RPMFusion.
If dependency installation fails, enable RPMFusion first (follow Fedora/RPMFusion docs), then rerun the installer.

---

## Secure Boot note

If `modprobe v4l2loopback` fails with a key error, Secure Boot is blocking the module.
You must disable Secure Boot or sign the module (MOK).
