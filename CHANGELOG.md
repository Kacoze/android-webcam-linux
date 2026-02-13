# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project uses SemVer-style tags.

## [Unreleased]

## [1.1.0] - 2026-02-12

- Refactored installer into modular files (`installer/main.sh`, `installer/lib/*.sh`); `install.sh` is now a thin wrapper.
- Installer now installs runtime scripts directly from `src/` (local repo) or downloads them by ref from GitHub.
- Removed dependency on installer heredoc rebuild; CI/release workflows updated accordingly.

## [1.0.2] - 2026-02-12

- Installer detects existing installation via PATH (/usr/bin or /usr/local/bin).

## [1.0.1] - 2026-02-12

- .deb packaging improvements (/usr/bin paths, prerm/postrm, license).
- Improved CLI contract (doctor schema_version, better exit codes, logs follow/sessions).
- Added manual integration matrix workflow and optional APT repo publishing workflow.

## [1.0.0] - 2026-02-12

- First stable release (renumbered).

## Versions below 1.0.0

## [0.9.2] - 2026-02-12

- Minisign signing enabled in release pipeline.

## [0.9.1] - 2026-02-12

- Release workflow hardened to publish even when signing is not configured.

## [0.9.0] - 2026-02-12

- Release notes generated from git history.
- Debian package artifacts and checksums.
- AUR packaging template.

## [0.8.0] - 2026-02-12

- One-liner hardening (bootstrap + checksum).
- Installer `--yes` and `--check-only`.
- `doctor` diagnostics and runtime logging improvements.

## [0.7.0] - 2026-02-12

- Release-based bootstrap flow and checksum validation.
