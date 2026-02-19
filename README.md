# ClipSlots

A lightweight clipboard slot manager for macOS. Save multiple clipboard items to numbered slots and paste them back anytime — text, images, files, rich text, anything.

## How It Works

- **Save:** `Ctrl+Option+{n}` — saves your current selection (or clipboard) to slot n
- **Paste:** `Ctrl+{n}` — pastes slot n content, just like Cmd+V

Works with everything: plain text, screenshots, images, files from Finder, rich text from browsers.

## Install

```bash
git clone https://github.com/olafglad/clipSlots.git
cd clipSlots
swift build
```

## Usage

### CLI

```bash
clipslots save 1      # Save clipboard to slot 1
clipslots paste 1     # Restore slot 1 to clipboard
clipslots list        # Show all slots
clipslots clear 1     # Clear slot 1
clipslots clear       # Clear all slots
clipslots config      # Show current config
clipslots config -e   # Edit config file
clipslots status      # Show daemon status
```

### Daemon (hotkeys)

```bash
clipslots start       # Start background daemon
clipslots stop        # Stop daemon
clipslots restart     # Restart daemon
```

**Requires Accessibility permission:** System Settings > Privacy & Security > Accessibility

### Configuration

Edit `~/.config/clipslots/config.toml`:

```toml
slots = 5
verbose = true

[keybinds]
save = "ctrl+option+{n}"
paste = "ctrl+{n}"
```

Config changes hot-reload — no need to restart the daemon.

**Available modifiers:** `ctrl`, `option`, `cmd`, `shift`
**Available keys:** `0-9`, `a-z`, `f1-f12`

## Requirements

- macOS 13+ (Ventura)
- Swift 5.7+

## License

MIT
