#!/usr/bin/env bash
set -euo pipefail

# Build a minimal APT repository from one or more .deb files.
# Output structure is suitable for GitHub Pages hosting.

out_dir="${1:-}"
shift || true

if [ -z "$out_dir" ] || [ "$#" -lt 1 ]; then
  echo "Usage: $0 <out_dir> <package.deb> [more.deb...]" >&2
  exit 1
fi

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "Error: dpkg-scanpackages not found (install dpkg-dev)." >&2
  exit 1
fi

if ! command -v apt-ftparchive >/dev/null 2>&1; then
  echo "Error: apt-ftparchive not found (install apt-utils)." >&2
  exit 1
fi

repo_root="$out_dir/apt"
dist="stable"
component="main"
arch="all"

pool_dir="$repo_root/pool/$component"
pkg_dir="$repo_root/dists/$dist/$component/binary-$arch"

rm -rf "$repo_root"
mkdir -p "$pool_dir" "$pkg_dir"

for deb in "$@"; do
  if [ ! -f "$deb" ]; then
    echo "Error: missing deb: $deb" >&2
    exit 1
  fi
  cp -f "$deb" "$pool_dir/"
done

(cd "$repo_root" && dpkg-scanpackages -m "pool/$component" /dev/null > "dists/$dist/$component/binary-$arch/Packages")
gzip -9c "$pkg_dir/Packages" > "$pkg_dir/Packages.gz"

cat > "$repo_root/apt-ftparchive.conf" <<EOF
Dir {
  ArchiveDir "${repo_root}";
};

Default {
  Packages::Compress ". gzip";
};

TreeDefault {
  Directory "pool/$component";
};

BinDirectory "dists/$dist/$component/binary-$arch" {
  Packages "dists/$dist/$component/binary-$arch/Packages";
};

APT::FTPArchive::Release {
  Origin "android-webcam-linux";
  Label "android-webcam-linux";
  Suite "$dist";
  Codename "$dist";
  Architectures "$arch";
  Components "$component";
  Description "android-webcam-linux APT repository";
};
EOF

(cd "$repo_root" && apt-ftparchive -c apt-ftparchive.conf release "dists/$dist" > "dists/$dist/Release")

echo "Built APT repo in: $repo_root"
echo "Repo URL base should be: https://<user>.github.io/<repo>/apt"
