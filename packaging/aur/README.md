Arch Linux (AUR) packaging notes

- Update `pkgver` to the latest tag.
- Replace `sha256sums=('SKIP')` with the real sha256 of the tag tarball.
- Then run `makepkg --printsrcinfo > .SRCINFO`.

This repository provides the PKGBUILD template; publishing to AUR requires an AUR git repository.
