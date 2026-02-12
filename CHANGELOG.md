# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project uses SemVer-style tags.

## [Unreleased]

## [2.5.2] - 2026-02-12

- Enabled minisign signing in release pipeline (install.sh signatures published for tagged releases).

## [2.5.1] - 2026-02-12

- Fix release workflow to publish even when optional signatures are not configured.

## [2.5.0] - 2026-02-12

- Added runtime `version` command and improved release upgrade detection.
- Release notes are generated from git history for tagged releases.
- Bootstrap supports optional minisign verification and stable-only tightening.
- Added Debian package checksum and AUR PKGBUILD template.

## [2.4.0] - 2026-02-12

- One-liner installation hardening (bootstrap + checksum).
- Added non-interactive installer mode and preflight checks.
- Added `doctor` diagnostics, JSON output, and better runtime logging.

## [2.3.0] - 2026-02-12

- Introduced release-based bootstrap flow and checksum validation.
- Added CI checks for script syntax and checksum integrity.
