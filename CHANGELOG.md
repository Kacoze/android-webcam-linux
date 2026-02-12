# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project uses SemVer-style tags.

## [Unreleased]

## [1.0.2] - 2026-02-12

- Installer detects existing installation via PATH (/usr/bin or /usr/local/bin).

## [1.0.1] - 2026-02-12

- .deb packaging improvements (/usr/bin paths, prerm/postrm, license).
- Improved CLI contract (doctor schema_version, better exit codes, logs follow/sessions).
- Added manual integration matrix workflow and optional APT repo publishing workflow.

## [1.0.0] - 2026-02-12

- First stable release (renumbered).

## Legacy (pre-1.0.0)

This section reflects earlier internal versioning that has been removed from GitHub Releases/tags.

### 2.5.x

- Minisign signing support in release pipeline.
- Release notes generated from git history.
- Debian package artifacts and checksums.

### 2.4.0

- One-liner hardening (bootstrap + checksum).
- Installer `--yes` and `--check-only`.
- `doctor` diagnostics and runtime logging improvements.

### 2.3.0

- Release-based bootstrap flow and checksum validation.
