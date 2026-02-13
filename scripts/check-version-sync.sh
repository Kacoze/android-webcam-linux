#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
  echo "Error: VERSION file missing" >&2
  exit 1
fi

ver="$(sed -n '1p' "$VERSION_FILE" | tr -d '[:space:]')"
if [ -z "$ver" ]; then
  echo "Error: VERSION is empty" >&2
  exit 1
fi

fail=0

if ! grep -q "ANDROID_WEBCAM_REF=\"v$ver\"" "$REPO_ROOT/README.md"; then
  echo "Error: README pin example is not v$ver" >&2
  fail=1
fi

if ! grep -q "^pkgver=$ver$" "$REPO_ROOT/packaging/aur/PKGBUILD"; then
  echo "Error: PKGBUILD pkgver is not $ver" >&2
  fail=1
fi

if ! grep -q "\[$ver\]" "$REPO_ROOT/CHANGELOG.md"; then
  echo "Error: CHANGELOG missing entry [$ver]" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "Version sync OK: $ver"
