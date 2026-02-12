# Support Playbook

Use this quick guide before opening an issue.

## 1) Run diagnostics first

```bash
android-webcam-ctl doctor
```

For automation / issue templates:

```bash
android-webcam-ctl doctor --json
```

Exit codes: `0=OK`, `1=FAIL`, `2=WARN`.

Latest runtime log (after start attempts):

`~/.local/state/android-webcam/logs/latest.log` (legacy: `/tmp/android-cam.log`)

Useful runtime commands:

```bash
android-webcam-ctl start --dry-run
android-webcam-ctl logs
android-webcam-ctl version
```

## 2) Common failures and fixes

### `/dev/video10` missing

```bash
lsmod | grep v4l2loopback
sudo modprobe v4l2loopback
```

If you get `Required key not available`, Secure Boot is blocking the module.

### `scrcpy` missing or too old

```bash
scrcpy --version
```

Need `>= 2.0`.

### Cannot connect to phone (`Connection refused`)

```bash
android-webcam-ctl setup
android-webcam-ctl status
adb connect YOUR_PHONE_IP:5555
```

### Camera not visible after stop/start

Run stop again and accept module reload password prompt:

```bash
android-webcam-ctl stop
android-webcam-ctl start
```

### Poor quality / lag

- Use 5GHz Wi-Fi and keep both devices on same LAN.
- Raise bitrate in config (`android-webcam-ctl config`).

## 3) What to include in issue report

- Output of `android-webcam-ctl doctor --json`
- Output of `./scripts/vm-smoke-test.sh` (if testing in VM)
- Distribution, kernel version, desktop session (X11/Wayland)
- Whether Secure Boot is enabled
