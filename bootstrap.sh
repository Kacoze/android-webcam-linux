#!/usr/bin/env bash
set -euo pipefail

REPO="${ANDROID_WEBCAM_REPO:-Kacoze/android-webcam-linux}"
REF="${ANDROID_WEBCAM_REF:-}"
ALLOW_UNVERIFIED="${ANDROID_WEBCAM_ALLOW_UNVERIFIED:-0}"

have() { command -v "$1" >/dev/null 2>&1; }

fetch_text() {
    local url="$1"
    if have curl; then
        curl -fsSL "$url"
    elif have wget; then
        wget -qO - "$url"
    else
        echo "Error: curl or wget is required." >&2
        exit 1
    fi
}

download_file() {
    local url="$1"
    local out="$2"
    if have curl; then
        curl -fsSL "$url" -o "$out"
    elif have wget; then
        wget -qO "$out" "$url"
    else
        echo "Error: curl or wget is required." >&2
        exit 1
    fi
}

extract_latest_release_tag() {
    local json="$1"
    printf "%s" "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]\+\)".*/\1/p' | sed -n '1p'
}

sha256_cmd() {
    if have sha256sum; then
        echo "sha256sum"
    elif have shasum; then
        echo "shasum"
    else
        echo ""
    fi
}

verify_checksum() {
    local target_file="$1"
    local checksum_file="$2"
    local cmd
    cmd="$(sha256_cmd)"
    if [ -z "$cmd" ]; then
        echo "Error: missing sha256 tool (sha256sum or shasum)." >&2
        return 1
    fi

    local expected
    expected=$(awk '{print $1}' "$checksum_file" | sed -n '1p')
    if [ -z "$expected" ]; then
        echo "Error: invalid checksum file format." >&2
        return 1
    fi

    local actual
    if [ "$cmd" = "sha256sum" ]; then
        actual=$(sha256sum "$target_file" | awk '{print $1}')
    else
        actual=$(shasum -a 256 "$target_file" | awk '{print $1}')
    fi

    if [ "$expected" != "$actual" ]; then
        echo "Error: checksum mismatch for install.sh" >&2
        echo "Expected: $expected" >&2
        echo "Actual:   $actual" >&2
        return 1
    fi
}

if [ -z "$REF" ]; then
    api_url="https://api.github.com/repos/${REPO}/releases/latest"
    latest_json="$(fetch_text "$api_url" || true)"
    REF="$(extract_latest_release_tag "$latest_json")"
    if [ -z "$REF" ]; then
        echo "Warning: failed to resolve latest release; falling back to main." >&2
        REF="main"
    fi
fi

raw_base="https://raw.githubusercontent.com/${REPO}/${REF}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

install_file="$tmp_dir/install.sh"
checksum_file="$tmp_dir/install.sh.sha256"

echo "Downloading installer from ${REPO}@${REF}..."
download_file "$raw_base/install.sh" "$install_file"

if download_file "$raw_base/install.sh.sha256" "$checksum_file" 2>/dev/null; then
    verify_checksum "$install_file" "$checksum_file"
    echo "Checksum verified."
else
    if [ "$ALLOW_UNVERIFIED" = "1" ]; then
        echo "Warning: checksum file not found; continuing (ANDROID_WEBCAM_ALLOW_UNVERIFIED=1)." >&2
    else
        echo "Error: checksum file not found for ref '${REF}'." >&2
        echo "Set ANDROID_WEBCAM_ALLOW_UNVERIFIED=1 to bypass (not recommended)." >&2
        exit 1
    fi
fi

exec bash "$install_file" "$@"
