import AppKit
import ApplicationServices
import HotKey
import Carbon

class HotkeyManager {
    private var hotkeys: [HotKey] = []
    private let storage: SlotStorage
    private let clipboard: Clipboard
    private let config: Config

    init(config: Config, storage: SlotStorage, clipboard: Clipboard) {
        self.config = config
        self.storage = storage
        self.clipboard = clipboard
    }

    func registerHotkeys() {
        unregisterAll()

        for slot in 1...config.slots {
            if let hk = createHotkey(pattern: config.keybinds.save, slot: slot, action: .save) {
                hotkeys.append(hk)
            }
            if let hk = createHotkey(pattern: config.keybinds.paste, slot: slot, action: .paste) {
                hotkeys.append(hk)
            }
        }

        print("Registered \(hotkeys.count) hotkeys for \(config.slots) slots")
    }

    func unregisterAll() {
        hotkeys.removeAll()
    }

    // MARK: - Private

    private enum Action { case save, paste }

    private func createHotkey(pattern: String, slot: Int, action: Action) -> HotKey? {
        guard let (key, modifiers) = parseKeybind(pattern: pattern, slot: slot) else {
            print("Warning: Could not parse keybind \"\(config.expandKeybind(pattern, slot: slot))\"")
            return nil
        }

        let hotkey = HotKey(key: key, modifiers: modifiers)
        let capturedSlot = slot

        hotkey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            switch action {
            case .save:  self.handleSave(slot: capturedSlot)
            case .paste: self.handlePaste(slot: capturedSlot)
            }
        }

        return hotkey
    }

    private func handleSave(slot: Int) {
        let originalContent = clipboard.getCurrentContent()
        let originalChangeCount = NSPasteboard.general.changeCount

        simulateKeyPress(key: CGKeyCode(8), flags: .maskCommand) // Cmd+C
        usleep(100_000)

        let newChangeCount = NSPasteboard.general.changeCount
        guard newChangeCount != originalChangeCount,
              let content = clipboard.getCurrentContent(), !content.isEmpty else {
            if !AXIsProcessTrusted() {
                print("[\(timestamp())] Save slot \(slot): no Accessibility permission")
            } else {
                print("[\(timestamp())] Save slot \(slot): nothing selected")
            }
            if let original = originalContent {
                _ = clipboard.setContent(original)
            }
            return
        }

        do {
            try storage.setSlot(slot, content: content)
            let preview = formatPreview(content)
            print("[\(timestamp())] Saved to slot \(slot): \"\(preview)\"")

            if let original = originalContent {
                _ = clipboard.setContent(original)
            }
        } catch {
            print("[\(timestamp())] Error saving to slot \(slot): \(error.localizedDescription)")
        }
    }

    private func handlePaste(slot: Int) {
        guard let content = storage.getSlot(slot), !content.isEmpty else {
            print("[\(timestamp())] Paste slot \(slot): empty")
            return
        }

        let originalContent = clipboard.getCurrentContent()

        guard clipboard.setContent(content) else {
            print("[\(timestamp())] Error pasting slot \(slot): failed to set clipboard")
            return
        }

        simulateKeyPress(key: CGKeyCode(9), flags: .maskCommand) // Cmd+V

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let original = originalContent {
                _ = self?.clipboard.setContent(original)
            }
        }

        let preview = formatPreview(content)
        print("[\(timestamp())] Pasted slot \(slot): \"\(preview)\"")
    }

    private func simulateKeyPress(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            print("[\(timestamp())] Error: could not create CGEvent")
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func formatPreview(_ content: String) -> String {
        let preview = content.count > 40 ? String(content.prefix(37)) + "..." : content
        return preview.replacingOccurrences(of: "\n", with: " ")
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    // MARK: - Keybind Parsing

    private func parseKeybind(pattern: String, slot: Int) -> (Key, NSEvent.ModifierFlags)? {
        let expanded = config.expandKeybind(pattern, slot: slot)
        let parts = expanded.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }

        guard parts.count >= 2 else { return nil }

        let keyString = parts.last!
        let modifierStrings = Array(parts.dropLast())

        guard let key = mapKey(keyString) else {
            print("Warning: Unknown key \"\(keyString)\"")
            return nil
        }

        var modifiers: NSEvent.ModifierFlags = []
        for mod in modifierStrings {
            guard let flag = mapModifier(mod) else {
                print("Warning: Unknown modifier \"\(mod)\"")
                return nil
            }
            modifiers.insert(flag)
        }

        return (key, modifiers)
    }

    private func mapModifier(_ s: String) -> NSEvent.ModifierFlags? {
        switch s {
        case "ctrl", "control":  return .control
        case "option", "alt":    return .option
        case "cmd", "command":   return .command
        case "shift":            return .shift
        default:                 return nil
        }
    }

    private func mapKey(_ s: String) -> Key? {
        switch s {
        case "0": return .zero
        case "1": return .one;  case "2": return .two;  case "3": return .three
        case "4": return .four; case "5": return .five;  case "6": return .six
        case "7": return .seven; case "8": return .eight; case "9": return .nine
        case "a": return .a; case "b": return .b; case "c": return .c
        case "d": return .d; case "e": return .e; case "f": return .f
        case "g": return .g; case "h": return .h; case "i": return .i
        case "j": return .j; case "k": return .k; case "l": return .l
        case "m": return .m; case "n": return .n; case "o": return .o
        case "p": return .p; case "q": return .q; case "r": return .r
        case "s": return .s; case "t": return .t; case "u": return .u
        case "v": return .v; case "w": return .w; case "x": return .x
        case "y": return .y; case "z": return .z
        case "f1": return .f1;   case "f2": return .f2;   case "f3": return .f3
        case "f4": return .f4;   case "f5": return .f5;   case "f6": return .f6
        case "f7": return .f7;   case "f8": return .f8;   case "f9": return .f9
        case "f10": return .f10; case "f11": return .f11; case "f12": return .f12
        default:  return nil
        }
    }
}
