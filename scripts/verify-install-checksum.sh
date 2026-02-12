#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Error: sha256sum is required." >&2
    exit 1
fi

sha256sum -c install.sh.sha256
