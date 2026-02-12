#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/src"
MOCKS_DIR="$REPO_ROOT/.ci/mocks"

rm -rf "$MOCKS_DIR"
mkdir -p "$MOCKS_DIR"

# Create mock commands
cat > "$MOCKS_DIR/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  connect)
    # pretend success
    exit 0
    ;;
  disconnect)
    exit 0
    ;;
  devices)
    echo "List of devices attached"
    exit 0
    ;;
  tcpip)
    exit 0
    ;;
  wait-for-usb-device)
    exit 0
    ;;
  shell)
    # minimal output for ip detection
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF

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

# Test environment
TEST_HOME="$REPO_ROOT/.ci/home"
rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME/.config/android-webcam" "$TEST_HOME/.local/bin"

# Provide scrcpy-server payload next to scrcpy for payload check paths
touch "$TEST_HOME/.local/bin/scrcpy-server"

# Ensure PATH picks our mocks and home scrcpy
export HOME="$TEST_HOME"
export PATH="$TEST_HOME/.local/bin:$MOCKS_DIR:$PATH"

# Use non-/dev sink for CI
export ANDROID_WEBCAM_V4L2_SINK="$TEST_HOME/video10"
touch "$ANDROID_WEBCAM_V4L2_SINK"

# Create config with valid IP
cat > "$TEST_HOME/.config/android-webcam/settings.conf" <<'EOF'
PHONE_IP="192.168.1.50"
CAMERA_FACING="back"
VIDEO_SIZE=""
BIT_RATE="8M"
EXTRA_ARGS="--no-audio"
SHOW_WINDOW="false"
RELOAD_V4L2_ON_STOP="false"
EOF

set +e
"$RUNTIME_DIR/android-webcam-ctl" doctor --json > "$REPO_ROOT/.ci/doctor.json"
rc=$?
set -e

if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "Unexpected doctor exit code: $rc" >&2
  cat "$REPO_ROOT/.ci/doctor.json" >&2 || true
  exit 1
fi

grep -q '"checks"' "$REPO_ROOT/.ci/doctor.json"
grep -q '"suggested_actions"' "$REPO_ROOT/.ci/doctor.json"

echo "Runtime CI tests passed. Doctor exit code: $rc"
