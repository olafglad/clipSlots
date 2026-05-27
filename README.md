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
  <img src="https://img.shields.io/github/stars/olafglad/clipSlots" alt="GitHub stars" />
  <img src="https://img.shields.io/github/v/release/olafglad/clipSlots" alt="GitHub release" />
  <img src="https://img.shields.io/github/downloads/olafglad/clipSlots/total" alt="GitHub downloads" />
  <img src="https://img.shields.io/github/license/olafglad/clipSlots" alt="License" />
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+" />
  <a href="https://clipslots.dev"><img src="https://img.shields.io/badge/website-clipslots.dev-7DDFB0" alt="Website" /></a>
</p>

---

## How it works

```bash
# Save your clipboard to slot 3
Ctrl + Option + 3

# Paste slot 3, just like Cmd+V
Ctrl + 3
```

That's it. Works with plain text, images, screenshots, files from Finder, rich text from browsers — anything your clipboard can hold. Keybindings are fully configurable.

<p align="center">
  <img src="docs/images/demo.gif" alt="ClipSlots terminal demo" width="800" />
</p>

## Why ClipSlots

- **9 slots, always there.** Save with one hotkey, paste with another. Slots persist until you clear them.
- **Works in every app.** System-wide hotkeys — no focus switching, no menubar fishing.
- **Not just text.** Images, RTF, HTML, file references. What you copy is what you paste.
- **Stays out of the way.** A launchd daemon. No menubar icon, no dock icon, no interruptions.

## Install

```bash
brew tap olafglad/clipslots
brew install clipslots
clipslots permissions   # grant accessibility (one-time)
clipslots start
```

Done. Hotkeys are live.

<details>
<summary>Other install methods</summary>

**[Download `ClipSlots.pkg`](https://github.com/olafglad/clipSlots/releases/latest/download/ClipSlots.pkg)** (always points at the latest release). Double-click to install, then run `clipslots permissions && clipslots start`.

**Build from source:**

```bash
git clone https://github.com/olafglad/clipSlots.git
cd clipSlots
swift build -c release
cp .build/release/clipslots ~/bin/
```

</details>

## Learn more

ClipSlots has 20+ commands — labels, locks, undo, swap/copy, export/import, peek, and more. The README keeps it short on purpose.

- **[clipslots.dev](https://clipslots.dev)** — overview, install, what it does
- **[clipslots.dev/docs](https://clipslots.dev/docs)** — full command reference & config

## Support

If ClipSlots saves you time:

- ⭐ [Star on GitHub](https://github.com/olafglad/clipSlots)
- ☕ [Buy me a coffee](https://ko-fi.com/olafglad)
- 💜 [GitHub Sponsors](https://github.com/sponsors/olafglad)

## License

MIT
