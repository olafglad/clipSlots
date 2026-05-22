# Changelog

All notable changes to ClipSlots are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## How to update

**Before tagging a release, add a new `## [X.Y.Z] - YYYY-MM-DD` section
below** describing what shipped (use `### Added`, `### Changed`,
`### Fixed`, `### Removed` subsections as appropriate), plus a matching
link reference at the bottom of the file. The release workflow
(`.github/workflows/release.yml`) extracts the section matching the tag
and prepends it to the GitHub Release body. If the section is missing,
the release ships with only install instructions.

## [1.4.0] - 2026-05-22

### Added
- `clipslots export <path>` writes all slots (including labels and
  manifest) to a tar archive at the given path. Refuses to overwrite an
  existing file.
- `clipslots import <path>` restores slots from a tar archive produced
  by `export`. Refuses to overwrite non-empty slots unless `--force` is
  passed. The existing `slots/` directory is renamed aside during the
  swap and restored if the move fails.

## [1.3.0] - 2026-05-21

### Added
- `clipslots open <slot>` opens a slot in the most appropriate app:
  text slots launch in `$EDITOR`, single files open in their default app,
  multi-file slots reveal the first file in Finder, images open in
  Preview, and rich text (RTF/HTML) opens in TextEdit/browser to
  preserve formatting. Errors clearly when `$EDITOR` is unset for plain
  text, when a stored file path no longer exists, or when the slot
  contains only opaque binary data.

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

[1.4.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.4.0
[1.3.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.3.0
[1.2.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.2.0
[1.1.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.1.0
[1.0.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.0.0
