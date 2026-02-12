#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/.ci/runtime}"

mkdir -p "$OUT_DIR"

extract_block() {
  local start_pat="$1"
  local end_pat="$2"
  local out_file="$3"

  awk -v start="$start_pat" -v end="$end_pat" '
    $0 ~ start {in_block=1; next}
    in_block && $0 ~ end {exit}
    in_block {print}
  ' "$REPO_ROOT/install.sh" > "$out_file"

  if [ ! -s "$out_file" ]; then
    echo "Error: failed to extract $out_file" >&2
    exit 1
  fi
}

# android-webcam-common
extract_block "cat << 'COMMONEOF'" "^COMMONEOF$" "$OUT_DIR/android-webcam-common"

# android-webcam-ctl
extract_block "cat << 'EOF'" "^EOF$" "$OUT_DIR/android-webcam-ctl"

chmod +x "$OUT_DIR/android-webcam-ctl"
chmod 0644 "$OUT_DIR/android-webcam-common"

echo "Extracted runtime scripts to: $OUT_DIR"
