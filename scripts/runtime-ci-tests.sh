#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/src"
CI_DIR="$REPO_ROOT/.ci"
MOCKS_DIR="$CI_DIR/mocks"

rm -rf "$CI_DIR"
mkdir -p "$CI_DIR" "$MOCKS_DIR"

write_mock_adb() {
  local devices_line="$1"
  cat > "$MOCKS_DIR/adb" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  connect) exit 0 ;;
  disconnect) exit 0 ;;
  devices)
    echo "List of devices attached"
    ${devices_line}
    exit 0
    ;;
  tcpip) exit 0 ;;
  wait-for-usb-device) exit 0 ;;
  shell) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/adb"
}

write_common_mocks() {
  cat > "$MOCKS_DIR/scrcpy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  echo "scrcpy 2.5"
  exit 0
fi
exit 0
EOF

  cat > "$MOCKS_DIR/lsmod" <<'EOF'
#!/usr/bin/env bash
echo "v4l2loopback 45056 0"
EOF

  cat > "$MOCKS_DIR/mokutil" <<'EOF'
#!/usr/bin/env bash
echo "SecureBoot disabled"
EOF

  cat > "$MOCKS_DIR/groups" <<'EOF'
#!/usr/bin/env bash
echo "user video"
EOF

  chmod +x "$MOCKS_DIR"/*
}

mk_test_home() {
  local name="$1"
  local home="$CI_DIR/home-$name"
  rm -rf "$home"
  mkdir -p "$home/.config/android-webcam" "$home/.local/bin"
  echo "$home"
}

write_config() {
  local home="$1"
  local sink="$2"
  cat > "$home/.config/android-webcam/settings.conf" <<EOF
PHONE_IP="192.168.1.50"
CAMERA_FACING="back"
VIDEO_SIZE=""
BIT_RATE="8M"
EXTRA_ARGS="--no-audio"
SHOW_WINDOW="false"
RELOAD_V4L2_ON_STOP="false"
V4L2_SINK="$sink"
DEFAULT_DEVICE_SERIAL=""
LAST_WORKING_ENDPOINT=""
DISABLE_ADB_WIFI_ON_STOP="false"
PRESET="meeting"
EOF
}

run_cmd() {
  local home="$1"
  shift
  export HOME="$home"
  export XDG_STATE_HOME="$home/.local/state"
  export PATH="$home/.local/bin:$MOCKS_DIR:$PATH"
  "$@"
}

expect_rc() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$expected" -ne "$actual" ]; then
    echo "Expected rc=$expected, got rc=$actual ($label)" >&2
    exit 1
  fi
}

write_common_mocks

# 1) doctor --json baseline (WARN is acceptable in CI environment)
write_mock_adb "echo -e 'emulator-5554\tdevice'"
home1=$(mk_test_home "doctor-ok")
sink1="$home1/video10"
touch "$sink1"
touch "$home1/.local/bin/scrcpy-server"
write_config "$home1" "$sink1"

set +e
run_cmd "$home1" "$RUNTIME_DIR/android-webcam-ctl" doctor --json > "$CI_DIR/doctor-ok.json"
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "Expected rc=0 or rc=2, got rc=$rc (doctor baseline)" >&2
  exit 1
fi
grep -q '"checks"' "$CI_DIR/doctor-ok.json"
grep -q '"suggested_actions"' "$CI_DIR/doctor-ok.json"
grep -q '"schema_version":1' "$CI_DIR/doctor-ok.json"
grep -q '"top_action"' "$CI_DIR/doctor-ok.json"

# 2) doctor --json fails when sink missing
home2=$(mk_test_home "doctor-sink-missing")
touch "$home2/.local/bin/scrcpy-server"
write_config "$home2" "$home2/missing-sink"

set +e
run_cmd "$home2" "$RUNTIME_DIR/android-webcam-ctl" doctor --json > "$CI_DIR/doctor-sink-missing.json"
rc=$?
set -e
expect_rc 1 "$rc" "doctor sink missing"
grep -q '"v4l2 sink"' "$CI_DIR/doctor-sink-missing.json"

# 3) start --dry-run prints scrcpy cmd and does not require adb connect
home3=$(mk_test_home "start-dry-run")
sink3="$home3/video10"
touch "$sink3"
touch "$home3/.local/bin/scrcpy-server"
write_config "$home3" "$sink3"

set +e
run_cmd "$home3" "$RUNTIME_DIR/android-webcam-ctl" start --dry-run > "$CI_DIR/start-dry-run.txt"
rc=$?
set -e
expect_rc 0 "$rc" "start --dry-run"
grep -q -- "--v4l2-sink=$sink3" "$CI_DIR/start-dry-run.txt"

# 4) logs --path prints path; logs fails if no log yet
home4=$(mk_test_home "logs")
touch "$home4/.local/bin/scrcpy-server"
sink4="$home4/video10"
touch "$sink4"
write_config "$home4" "$sink4"

set +e
run_cmd "$home4" "$RUNTIME_DIR/android-webcam-ctl" logs --path > "$CI_DIR/logs-path.txt"
rc=$?
set -e
expect_rc 0 "$rc" "logs --path"
grep -q "latest.log" "$CI_DIR/logs-path.txt"

set +e
run_cmd "$home4" "$RUNTIME_DIR/android-webcam-ctl" logs > "$CI_DIR/logs.txt"
rc=$?
set -e
expect_rc 1 "$rc" "logs without log"

# Create a log by dry-run start
run_cmd "$home4" "$RUNTIME_DIR/android-webcam-ctl" start --dry-run >/dev/null
set +e
run_cmd "$home4" "$RUNTIME_DIR/android-webcam-ctl" logs --tail 5 > "$CI_DIR/logs-after.txt"
rc=$?
set -e
expect_rc 0 "$rc" "logs after start"

# 5) start --dry-run fails when scrcpy payload missing for ~/.local/bin/scrcpy
home5=$(mk_test_home "payload-missing")
sink5="$home5/video10"
touch "$sink5"
write_config "$home5" "$sink5"
cat > "$home5/.local/bin/scrcpy" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  echo "scrcpy 2.5"
  exit 0
fi
exit 0
EOF
chmod +x "$home5/.local/bin/scrcpy"

set +e
run_cmd "$home5" "$RUNTIME_DIR/android-webcam-ctl" start --dry-run > "$CI_DIR/payload-missing.txt" 2>&1
rc=$?
set -e
expect_rc 16 "$rc" "payload missing"
grep -q "scrcpy server payload is missing" "$CI_DIR/payload-missing.txt"

# 6) repair succeeds with USB device and writes endpoint/serial
home6=$(mk_test_home "repair")
sink6="$home6/video10"
touch "$sink6"
touch "$home6/.local/bin/scrcpy-server"
write_config "$home6" "$sink6"

cat > "$home6/.local/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  devices)
    echo "List of devices attached"
    echo -e "usb-serial-01\tdevice"
    ;;
  -s)
    serial="${2:-}"
    shift 2
    case "${1:-}" in
      shell)
        if [ "${2:-}" = "ip" ]; then
          echo "2: wlan0    inet 192.168.1.77/24 brd 192.168.1.255 scope global wlan0"
        fi
        ;;
      tcpip)
        ;;
    esac
    ;;
  connect)
    ;;
  disconnect)
    ;;
  wait-for-usb-device)
    ;;
esac
exit 0
EOF
chmod +x "$home6/.local/bin/adb"

set +e
run_cmd "$home6" "$RUNTIME_DIR/android-webcam-ctl" repair > "$CI_DIR/repair.txt"
rc=$?
set -e
expect_rc 0 "$rc" "repair success"
grep -q 'DEFAULT_DEVICE_SERIAL="usb-serial-01"' "$home6/.config/android-webcam/settings.conf"
grep -q 'LAST_WORKING_ENDPOINT="192.168.1.77:5555"' "$home6/.config/android-webcam/settings.conf"

# 7) preset command updates config values
set +e
run_cmd "$home6" "$RUNTIME_DIR/android-webcam-ctl" preset low-latency > "$CI_DIR/preset.txt"
rc=$?
set -e
expect_rc 0 "$rc" "preset low-latency"
grep -q 'BIT_RATE="6M"' "$home6/.config/android-webcam/settings.conf"
grep -q 'PRESET="low-latency"' "$home6/.config/android-webcam/settings.conf"

echo "Runtime CI tests passed."
