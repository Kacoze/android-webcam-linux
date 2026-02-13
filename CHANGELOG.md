# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project uses SemVer-style tags.

## [Unreleased]

## [1.2.6] - 2026-02-13

- Added automatic post-stop cleanup when camera is closed via window/system "Quit" action.
- Closing the camera window now triggers the same v4l2loopback reload path as `android-webcam-ctl stop`.

## [1.2.5] - 2026-02-13

- Installer now offers enabling passwordless Stop Camera during setup and clearly states it creates a sudoers rule.
- Added non-interactive flags `--yes` for `enable-passwordless-stop` and `disable-passwordless-stop`.
- Clarified passwordless confirmation prompts to explicitly mention writing/removing sudoers rules.

## [1.2.4] - 2026-02-13

- Added `android-webcam-ctl update` command with `--check` / `--yes` / `--ref` options.
- Added desktop menu action `Update` (right-click on Camera Phone icon).

## [1.2.3] - 2026-02-13

- Added optional passwordless Stop via a narrow sudoers rule for reloading `v4l2loopback`.
- Stop now falls back to authenticated reload (polkit/sudo) when passwordless is not enabled.
- Added `enable-passwordless-stop`, `disable-passwordless-stop`, and `passwordless-stop-status` commands.
- Doctor now reports passwordless stop status and suggests enabling it as an optional convenience.
- Expanded runtime CI tests to cover passwordless status parsing and stop fallback behavior.

## [1.2.2] - 2026-02-13

- Set front camera as default for new installs/configs.
- Fixed terminal desktop actions to close on Enter (no interactive shell).

## [1.2.1] - 2026-02-13

- Removed `repair` command and menu action to keep UX focused on `setup` only.
- Kept USB auto-repair fallback internally in `start`.
- Fixed single-device `setup` path to persist `DEFAULT_DEVICE_SERIAL` consistently.

## [1.2.0] - 2026-02-13

- Added USB-first convenience features: automatic USB repair fallback in `start` and faster `setup` flow.
- Added multi-device preference via `DEFAULT_DEVICE_SERIAL` and persisted `LAST_WORKING_ENDPOINT`.
- Added notification throttling and `doctor --json` field `top_action`.
- Added presets command (`preset meeting|hq|low-latency`) and status visibility of active profile/device state.
- Added optional security hygiene on stop via `DISABLE_ADB_WIFI_ON_STOP`.
- Kept desktop/menu actions focused on Setup/Stop/Logs for simpler UX.

## [1.1.1] - 2026-02-13

- Fixed installer cleanup bug causing `tmp: unbound variable` after successful install.
- Removed function-level RETURN trap pattern to prevent similar shell cleanup errors.

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
