<p align="center">
  <img src="docs/images/mascot.png" alt="ClipSlots mascot" width="200" />
</p>

<h1 align="center">ClipSlots</h1>

<p align="center">
  <strong>Stop losing what you just copied.</strong><br />
  9 keyboard-triggered clipboard slots for macOS.<br />
  Press a hotkey to save, press another to paste — in any app, instantly.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-blueviolet" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  <a href="https://clipslots.dev"><img src="https://img.shields.io/badge/website-clipslots.dev-7DDFB0" alt="Website" /></a>
</p>

---

## How it works

```
Ctrl + Option + 3  →  saves your clipboard to slot 3
Ctrl + 3           →  pastes slot 3, just like Cmd+V
```

That's it. Works with plain text, images, screenshots, files from Finder, rich text from browsers — anything your clipboard can hold.

<!-- TODO: terminal demo GIF here -->

## Why ClipSlots

**9 clipboard slots** — Copy something, press `Ctrl+Opt+3`, it's saved. Press `Ctrl+3` later, it's back. Slots persist until you clear them.

**Works in every app** — System-wide hotkeys that work in VS Code, Chrome, Figma, Terminal. No focus switching.

**Not just text** — Images, RTF, HTML, file references. What you copy is what you paste.

**Starts on login, stays hidden** — A launchd daemon. No menubar icon, no dock icon, no interruptions.

**One config file** — Edit `~/.config/clipslots/config.toml` to change hotkeys, slot count, and logging. Hot-reloads on save.

**Full CLI control** — `clipslots status`, `clipslots list`, `clipslots config --edit`. Script it, alias it, pipe it.

## Install

```bash
git clone https://github.com/olafglad/clipSlots.git
cd clipSlots
swift build -c release
sudo cp .build/release/clipslots /usr/local/bin/
```

Grant accessibility permission (one-time):

```bash
clipslots permissions
```

> System Settings > Privacy & Security > Accessibility > enable `clipslots`

Start the daemon:

```bash
clipslots start
```

Done. Hotkeys are live.

## Usage

### CLI

| Command | What it does |
|---|---|
| `clipslots save 3` | Save clipboard to slot 3 |
| `clipslots paste 3` | Restore slot 3 to clipboard |
| `clipslots list` | Show all slots with content preview |
| `clipslots clear 3` | Clear slot 3 |
| `clipslots clear` | Clear all slots |
| `clipslots status` | Show daemon status and config |
| `clipslots config` | Show current configuration |
| `clipslots config -e` | Open config file in your editor |

### Daemon

| Command | What it does |
|---|---|
| `clipslots start` | Start the background daemon |
| `clipslots stop` | Stop the daemon |
| `clipslots restart` | Restart the daemon |

### Configuration

Edit `~/.config/clipslots/config.toml`:

```toml
slots = 5
verbose = true

[keybinds]
save = "ctrl+option+{n}"
paste = "ctrl+{n}"
```

**Modifiers:** `ctrl`, `option`, `cmd`, `shift`
**Keys:** `0-9`, `a-z`, `f1-f12`

Config changes hot-reload — no restart needed.

## Your Mac won't notice it

One Swift binary. No GUI, no Electron, no subscription.

<p align="center">
  <img src="docs/images/monitor-cpu.png" alt="0% CPU usage" width="340" />
  <img src="docs/images/monitor-ram.png" alt="~10MB RAM usage" width="340" />
</p>

## Requirements

- macOS 13+ (Ventura)
- Swift 5.7+

## Links

- [clipslots.dev](https://clipslots.dev) — Website
- [Ko-fi](https://ko-fi.com/olafglad) — Buy me a coffee
- [GitHub Sponsors](https://github.com/sponsors/olafglad) — Sponsor this project

## License

MIT
