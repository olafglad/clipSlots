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

## [1.13.1] - 2026-05-27

### Changed
- `clipslots status` logo redrawn as an actual clipboard silhouette: a
  rounded clip on top, paper rectangle below, and the 3×3 slot grid
  nested inside. Rendered in magenta to match the project's brand color
  (favicon). Section headers stay cyan; ●/○ indicators keep their
  semantic green/red.
- The logo is now vertically centered against the sections column
  instead of top-anchored, so the two-column layout looks balanced
  regardless of how many lines the right side prints.

## [1.13.0] - 2026-05-27

### Fixed
- Config silently falling back to defaults: every command used to print
  `Warning: Could not parse config: ... Using defaults.` whenever the
  TOML omitted any optional key (e.g. a missing `expire_after_hours` or
  `feedback`). Root cause was Swift's synthesized `Codable` init not
  honoring `decodeIfPresent` semantics through TOMLDecoder 0.2.2.
  `Config` now has an explicit `init(from:)` mirroring the existing
  `Keybinds` pattern; partial configs decode without warnings and the
  daemon actually uses the values from the file.

### Added
- `clipslots status` rewritten as a fastfetch-style two-column layout:
  ASCII logo on the left, four sections (Daemon, Permissions, Slots,
  Keybinds) on the right. Includes daemon PID and uptime when running,
  ●/○ indicators for binary state, and the configured/used/locked slot
  counts. Stacks plain text (no logo) when piped, under `NO_COLOR=1`,
  or in a narrow terminal.
- `clipslots config` is now a parent command with three subcommands:
  - `clipslots config edit` — opens the config file in `$EDITOR`
    (replaces the old `--edit` flag; the flag is kept hidden for
    backward compat).
  - `clipslots config validate` — parses + validates the config file,
    exits 0 with "Config OK" or exits 1 with a specific error and the
    file path on stderr. Useful in pre-commit hooks and CI.
  - `clipslots config path` — prints the absolute path to the config
    file. Script-friendly: `cd "$(dirname "$(clipslots config path)")"`.
- Per-command usage examples (`discussion:` text under `--help`) for
  `save`, `paste`, `peek`, `list`, `open`, `label`, `lock`, `unlock`,
  `undo`, `swap`, `copy`, `export`, `import`, `clear`, `status`, and
  every `config` subcommand.

### Changed
- Central styling module (`Core/Style.swift`) replaces ad-hoc ANSI in
  `list`. Honors `NO_COLOR` (force off), `CLICOLOR_FORCE=1` (force on),
  and `isatty` (default). No visible change to `clipslots list`; this
  unblocks consistent styling across future commands.
- `clipslots config` output reuses the same section-header /
  key-value layout as the new `status` view (no logo). Now also surfaces
  `expire_after_hours` and `feedback` values directly.

## [1.12.0] - 2026-05-27

### Added
- `clipslots swap <a> <b>` exchanges the contents of two slots, and
  `clipslots copy <src> <dst>` duplicates one slot's content into
  another. Useful when you realise after saving "this should've been
  slot 1" and the source app has already moved on.

### Behavior
- Both commands respect locks (#6). `swap` refuses if either slot is
  locked; `copy` refuses if the destination is locked. The source of a
  copy is read-only, so source locks don't block.
- Both commands refuse with a non-zero exit when the source is empty
  (and for `swap`, when either side is empty). Same-slot operations
  (`swap 3 3`, `copy 3 3`) are validation errors.
- Both commands create undo (#12) snapshots before mutating: `swap`
  writes one prev per side so each slot can be undone independently;
  `copy` writes one prev for the destination. Underlying storage uses
  the same atomic rename pattern as `setSlot` (`.swap_*` stash dirs are
  cleaned up on daemon start if a crash ever leaves one behind).

## [1.11.0] - 2026-05-27

### Added
- `clipslots undo <n>` restores slot `n` to its previous content.
  One level of history is kept per slot: every successful save (CLI or
  hotkey) and every append snapshots the prior content first. Running
  `undo` again on the same slot round-trips back to where you started,
  since `undo` swaps current and prev rather than consuming prev.

### Behavior
- Locked slots refuse `undo` with the same message as `clear`/save —
  lock is the hard guarantee, undo never bypasses it.
- Slots with no prior content (never written, or already undone twice
  in a row past the round-trip) return a non-zero "No previous content"
  error.
- `clear` and `clear --force` wipe the undo history alongside the slot
  itself. The expiry sweep does the same. Otherwise `clear` followed by
  `undo` would resurrect content the user just asked to delete.
- Storage cost is at most one extra copy per slot (under
  `slots/.prev/<n>/`). The snapshot lives outside the slot dir so the
  atomic save-swap doesn't wipe it.

## [1.10.0] - 2026-05-27

### Added
- Optional sound feedback on successful save/paste/append from a hotkey.
  Set `feedback = "sound"` in `~/.config/clipslots/config.toml` to enable;
  default is `"off"`. Plays the macOS system "Pop" sound — short and
  unobtrusive. Useful confirmation that the hotkey actually fired,
  especially in apps where the save/paste action has no visible effect.

### Behavior
- Fires only on the success path. Skipped cases (locked target, empty
  clipboard, non-text append source/target, missing Accessibility
  permission, storage errors) stay silent — logs already cover them.
- Daemon hotkeys only. The CLI `save` / `paste` commands never play a
  sound regardless of the config value; they're typically scripted.
- Volume follows the system sound effects slider and is muted by Do Not
  Disturb / Focus modes, matching every other macOS UI sound.

## [1.9.0] - 2026-05-27

### Added
- Optional slot expiry: a new top-level `expire_after_hours` config key
  enables the daemon to auto-clear non-locked slots whose last-write
  mtime exceeds the threshold. Disabled by default — uncomment the
  example line in `~/.config/clipslots/config.toml` to opt in. The
  daemon sweeps once at startup and then once per hour while enabled.
  Locked slots are exempt; per-slot mtimes are the age basis (matches
  `list --verbose` age semantics).
- Inline age in default `clipslots list`: every non-empty slot row now
  ends with `(Xm ago)` so freshness is visible without `--verbose`.

### Behavior
- **Grace period on first enable:** when the feature transitions from
  disabled to enabled, the moment is persisted in
  `slots/expiry_state.json`. The age basis for each slot is
  `max(slot_mtime, enabledAt)`, so already-stale slots get a fresh
  full TTL window before they can be cleared. Disabling the feature
  removes the marker, so a later re-enable earns a fresh grace period.
- Each cleared slot is logged on its own line (`Expired slot N (age …)`)
  when daemon `verbose = true`. The grace-period boundary is also
  logged once on enable (`existing slots will not be cleared before
  <ISO timestamp>`).

## [1.8.1] - 2026-05-26

### Fixed
- `clipslots list -v` now shows accurate per-slot ages. Previously the
  manifest rebuild stamped every entry with the current wall-clock
  time, so all slots reported the same `age` (whatever moment the
  manifest was last rebuilt). The manifest now reads each slot
  directory's modification time — which `setSlot`'s atomic rename
  pattern keeps correct — so ages reflect when each slot was actually
  written. Pre-1.8.1 ages will normalise after the next save (which
  triggers a fresh manifest rebuild).

## [1.8.0] - 2026-05-26

### Added
- `clipslots list --verbose` / `-v` expands each slot into a multi-line
  block showing byte size, full pasteboard type list, age (relative
  time since last update), and lock state alongside the existing
  description. Pure rendering — no storage or manifest changes. Default
  compact output is unchanged when the flag is absent.

### Behavior
- Verbose output composes cleanly with `--grep`: filter is applied
  first, then the matching slots render in verbose form.
- Empty slots still render as `(empty)` with no metadata block.
- Slots present on disk but missing from the manifest cache fall back
  to header + description only; size/types/age require manifest data
  (which is rebuilt on the next save).

## [1.7.0] - 2026-05-26

### Added
- `clipslots peek <slot>` prints the text content of a slot to stdout.
  Designed for shell composition: `clipslots peek 3 | jq .`,
  `diff <(clipslots peek 1) <(clipslots peek 2)`,
  `TOKEN=$(clipslots peek 7)`, etc.
- `--truncate N` flag on `peek` for opt-in character limiting (no
  truncation by default so pipelines stay byte-faithful).

### Behavior
- A trailing newline is appended only when stdout is a TTY, so piped
  output is byte-exact with the saved clipboard contents.
- Empty slots exit 0 with no output (matches `cat /dev/null`).
- Non-text slots (images, files, binary) print a one-line description
  to stderr and exit 2; stdout stays empty so callers like `jq` see no
  garbage input.
- Invalid slot numbers exit with the standard argument-parser
  validation error (exit 64).
- Locked slots are readable — peek never mutates and is unaffected by
  `lock` / `unlock`.

## [1.6.0] - 2026-05-22

### Added
- Optional append-mode hotkey (`keybinds.append` in
  `~/.config/clipslots/config.toml`). When set (e.g.
  `"ctrl+option+shift+{n}"`), pressing the hotkey appends the current
  clipboard text to slot N instead of overwriting it. Empty by default
  — append is opt-in and existing setups are unchanged.
- Configurable separator between existing slot text and the appended
  text via `keybinds.append_separator` (default `"\n"`).

### Behavior
- Append skips with a log line (no destruction) when the target slot is
  locked, when the existing slot contents are non-text, or when the
  incoming clipboard is non-text.
- Appending to an empty slot writes the incoming text as a normal save
  (no leading separator).
- Appending to a rich-text slot (RTF/HTML with plain-text fallback)
  collapses the slot to pure plain text and logs the collapse.
- `updatedAt` refreshes on each append (folds into TTL plans later).

## [1.5.0] - 2026-05-22

### Added
- `clipslots lock <slot>` marks a slot read-only; subsequent save hotkey
  presses for that slot log "locked, skipping" and `clipslots save <slot>`
  exits non-zero with a hint to unlock first. `clipslots unlock <slot>`
  clears the lock.
- Locked slots display a 🔒 marker (or `[L]` when piped) next to the slot
  number in `clipslots list`.
- `clipslots clear` is now lock-aware: clearing a single locked slot
  refuses unless `--force` is passed. `clipslots clear` with locked slots
  present prompts interactively with three options (clear all, keep
  locked, abort). The new `--force` flag clears every slot including
  locked ones, and `--keep-locked` clears only unlocked slots. In
  non-interactive contexts with locked slots present, `clear` refuses
  with a message pointing at the flags.
- Lock state is persisted at `~/.local/share/clipslots/slots/locks.json`
  and surfaced as an optional `locked` field on each manifest entry.

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

[1.13.1]: https://github.com/olafglad/clipSlots/releases/tag/v1.13.1
[1.13.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.13.0
[1.12.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.12.0
[1.11.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.11.0
[1.10.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.10.0
[1.9.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.9.0
[1.8.1]: https://github.com/olafglad/clipSlots/releases/tag/v1.8.1
[1.8.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.8.0
[1.7.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.7.0
[1.6.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.6.0
[1.5.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.5.0
[1.4.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.4.0
[1.3.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.3.0
[1.2.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.2.0
[1.1.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.1.0
[1.0.0]: https://github.com/olafglad/clipSlots/releases/tag/v1.0.0
