# Changelog

All notable changes to ClipSlots are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-05-20

### Added
- `clipslots list --grep <pattern>` filters slots whose label or content
  preview contains the pattern (case-insensitive). Non-matching slots are
  hidden from output.

## [1.1.0] - 2026-05-12

### Added
- `clipslots label <slot> <name>` sets a human-readable label for a slot;
  pass no name to clear it. Labels appear as a dedicated column in
  `clipslots list` whenever any slot has one.
- Manifest schema gained an optional `version` field (current: 1) to support
  future migrations without breaking older manifests.

### Changed
- `clipslots list` now renders an aligned label column when labels exist.
  When no slot has a label, output is unchanged from 1.0.0.

## [1.0.0] - 2026-02-24

Initial public release.

### Added
- 9 clipboard slots saved/pasted via global hotkeys
  (`ctrl+option+{1..9}` to save, `ctrl+shift+option+{1..9}` to paste).
- Hidden launchd daemon (`clipslots start` / `stop` / `restart` / `status`).
- TOML config at `~/.config/clipslots/config.toml` with hot-reload.
- Rich pasteboard support (text, RTF, images, files) preserved across
  save/paste round-trips.
- Per-slot atomic storage under `~/.local/share/clipslots/slots/`.
- `clipslots list` / `clear` / `permissions` / `config` commands.
- Universal binary (`arm64` + `x86_64`) shipped via `.pkg` and `.tar.gz`
  on every `v*` tag.

[1.2.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.2.0
[1.1.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.1.0
[1.0.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.0.0
