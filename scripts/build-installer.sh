#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

INSTALLER_IN="$REPO_ROOT/install.sh"
COMMON_SRC="$REPO_ROOT/src/android-webcam-common"
RUNTERM_SRC="$REPO_ROOT/src/android-webcam-run-in-terminal"
CTL_SRC="$REPO_ROOT/src/android-webcam-ctl"

if [ ! -f "$INSTALLER_IN" ]; then
  echo "Error: install.sh not found" >&2
  exit 1
fi
for f in "$COMMON_SRC" "$RUNTERM_SRC" "$CTL_SRC"; do
  if [ ! -f "$f" ]; then
    echo "Error: missing source file: $f" >&2
    exit 1
  fi
done

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT

awk \
  -v common_src="$COMMON_SRC" \
  -v runterm_src="$RUNTERM_SRC" \
  -v ctl_src="$CTL_SRC" \
  '
  function emit_file(path,   line) {
    while ((getline line < path) > 0) {
      print line
    }
    close(path)
  }
  BEGIN {
    mode = "copy"
  }
  {
    if (mode == "skip_common") {
      if ($0 ~ /^COMMONEOF$/) { print; mode = "copy" }
      next
    }
    if (mode == "skip_runterm") {
      if ($0 ~ /^RUNTERMEOF$/) { print; mode = "copy" }
      next
    }
    if (mode == "skip_ctl") {
      if ($0 ~ /^EOF$/) { print; mode = "copy" }
      next
    }

    # Replace embedded android-webcam-common block
    if ($0 ~ /cat << '\''COMMONEOF'\'' > "\$TMP_COMMON"/) {
      print
      emit_file(common_src)
      mode = "skip_common"
      next
    }

    # Replace embedded android-webcam-run-in-terminal block
    if ($0 ~ /cat << '\''RUNTERMEOF'\'' > "\$TMP_RUNTERM"/) {
      print
      emit_file(runterm_src)
      mode = "skip_runterm"
      next
    }

    # Replace embedded android-webcam-ctl block
    if ($0 ~ /cat << '\''EOF'\'' > "\$TMP_CTL"/) {
      print
      emit_file(ctl_src)
      mode = "skip_ctl"
      next
    }

    print
  }
  ' "$INSTALLER_IN" > "$tmp_out"

chmod --reference="$INSTALLER_IN" "$tmp_out" 2>/dev/null || chmod 0755 "$tmp_out"
mv "$tmp_out" "$INSTALLER_IN"

echo "Updated install.sh from src/*"
