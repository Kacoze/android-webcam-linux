#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
if [ -z "$tag" ]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

if ! git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Error: tag not found: $tag" >&2
  exit 1
fi

prev_tag=""
if git describe --tags --abbrev=0 "${tag}^" >/dev/null 2>&1; then
  prev_tag="$(git describe --tags --abbrev=0 "${tag}^")"
fi

echo "## Highlights"
echo "- Release $tag"
echo ""

if [ -n "$prev_tag" ]; then
  echo "## Changes since $prev_tag"
  echo ""
  git log --no-merges --pretty=format:'- %s (%h)' "$prev_tag..$tag" || true
else
  echo "## Changes"
  echo ""
  git log --no-merges --pretty=format:'- %s (%h)' "$tag" || true
fi

echo ""
echo ""
echo "## Installation (one-liner)"
echo "\`\`\`bash"
echo "curl -fsSL https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/bootstrap.sh | bash"
echo "\`\`\`"
echo ""
echo "## Verifiable install (stable only)"
echo "\`\`\`bash"
echo "ANDROID_WEBCAM_STABLE_ONLY=1 ANDROID_WEBCAM_REF=\"$tag\" \\\"\n  curl -fsSL https://raw.githubusercontent.com/Kacoze/android-webcam-linux/main/bootstrap.sh | bash"
echo "\`\`\`"
