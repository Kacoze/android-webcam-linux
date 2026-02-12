#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Error: sha256sum is required." >&2
    exit 1
fi

cd "$REPO_ROOT"
if [ -f "$REPO_ROOT/scripts/build-installer.sh" ] && [ -d "$REPO_ROOT/src" ]; then
    "$REPO_ROOT/scripts/build-installer.sh" >/dev/null
fi
sha256sum install.sh > install.sh.sha256
echo "Updated install.sh.sha256"
