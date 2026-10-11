import Foundation
import TOMLDecoder

public struct Config: Codable {
    public var slots: Int = 5
    public var verbose: Bool = true
    public var expire_after_hours: Int? = nil
    public var feedback: String = "off"
    public var keybinds: Keybinds = Keybinds()

    public init() {}

    public init(from decoder: Decoder) throws {
        // NOTE: every new stored property MUST be added here, not just declared above,
        // or it will silently always read as its default. See Keybinds for the pattern.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slots              = try c.decodeIfPresent(Int.self,      forKey: .slots)              ?? 5
        verbose            = try c.decodeIfPresent(Bool.self,     forKey: .verbose)            ?? true
        expire_after_hours = try c.decodeIfPresent(Int.self,      forKey: .expire_after_hours)
        feedback           = try c.decodeIfPresent(String.self,   forKey: .feedback)           ?? "off"
        keybinds           = try c.decodeIfPresent(Keybinds.self, forKey: .keybinds)           ?? Keybinds()
    }

    public struct Keybinds: Codable {
        public var save: String = "ctrl+option+{n}"
        public var paste: String = "ctrl+{n}"
        public var append: String = ""
        public var append_separator: String = "\n"
        /// Opens the menubar app's popover. Read only by ClipSlots.app;
        /// the CLI daemon ignores it. Empty string disables the shortcut.
        public var popover: String = "ctrl+option+v"

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            save = try c.decodeIfPresent(String.self, forKey: .save) ?? "ctrl+option+{n}"
            paste = try c.decodeIfPresent(String.self, forKey: .paste) ?? "ctrl+{n}"
            append = try c.decodeIfPresent(String.self, forKey: .append) ?? ""
            append_separator = try c.decodeIfPresent(String.self, forKey: .append_separator) ?? "\n"
            popover = try c.decodeIfPresent(String.self, forKey: .popover) ?? "ctrl+option+v"
        }
    }

    public static var `default`: Config { Config() }

    public func validate() throws {
        guard (1...10).contains(slots) else {
            throw ConfigError.invalidSlotCount(slots)
        }
        if let hours = expire_after_hours, hours <= 0 {
            throw ConfigError.invalidExpireHours(hours)
        }
        guard ["off", "sound", "visual", "both"].contains(feedback) else {
            throw ConfigError.invalidFeedback(feedback)
        }
        try validateKeybindPattern(keybinds.save, type: "save")
        try validateKeybindPattern(keybinds.paste, type: "paste")
        if !keybinds.append.isEmpty {
            try validateKeybindPattern(keybinds.append, type: "append")
        }
        if !keybinds.popover.isEmpty {
            try validateFixedKeybind(keybinds.popover, type: "popover")
        }
    }

    /// Validates a single fixed combo (no `{n}` placeholder), e.g. "ctrl+option+v".
    private func validateFixedKeybind(_ combo: String, type: String) throws {
        let parts = combo.split(separator: "+")
        guard parts.count >= 2, !combo.contains("{n}") else {
            throw ConfigError.invalidKeybindFormat(type: type, pattern: combo)
        }
        let validModifiers = Set(["ctrl", "control", "option", "alt", "cmd", "command", "shift"])
        for modifier in parts.dropLast().map({ String($0).lowercased() }) {
            guard validModifiers.contains(modifier) else {
                throw ConfigError.invalidModifier(modifier: modifier, type: type)
            }
        }
    }

    private func validateKeybindPattern(_ pattern: String, type: String) throws {
        guard pattern.contains("{n}") else {
            throw ConfigError.missingPlaceholder(type: type, pattern: pattern)
        }

        let parts = pattern.replacingOccurrences(of: "{n}", with: "1").split(separator: "+")
        guard parts.count >= 2 else {
            throw ConfigError.invalidKeybindFormat(type: type, pattern: pattern)
        }

        let validModifiers = Set(["ctrl", "control", "option", "alt", "cmd", "command", "shift"])
        for modifier in parts.dropLast().map({ String($0).lowercased() }) {
            guard validModifiers.contains(modifier) else {
                throw ConfigError.invalidModifier(modifier: modifier, type: type)
            }
        }
    }

    public func expandKeybind(_ pattern: String, slot: Int) -> String {
        pattern.replacingOccurrences(of: "{n}", with: String(slot))
    }
}

public enum ConfigError: LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case invalidSlotCount(Int)
    case invalidExpireHours(Int)
    case invalidFeedback(String)
    case missingPlaceholder(type: String, pattern: String)
    case invalidKeybindFormat(type: String, pattern: String)
    case invalidModifier(modifier: String, type: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Config file not found. Creating default configuration."
        case .invalidFormat(let error):
            return "Config error in ~/.config/clipslots/config.toml: \(error). Using defaults."
        case .invalidSlotCount(let count):
            return "Invalid slot count: \(count). Must be between 1 and 10."
        case .invalidExpireHours(let hours):
            return "Invalid expire_after_hours: \(hours). Must be a positive integer (or omit the key to disable)."
        case .invalidFeedback(let value):
            return "Invalid feedback: \"\(value)\". Must be \"off\", \"sound\", \"visual\" or \"both\"."
        case .missingPlaceholder(let type, let pattern):
            return "Invalid keybind for \(type): \"\(pattern)\" missing {n} placeholder."
        case .invalidKeybindFormat(let type, let pattern):
            return "Invalid keybind format for \(type): \"\(pattern)\". Expected format: modifier+modifier+{n}"
        case .invalidModifier(let modifier, let type):
            return "Invalid modifier \"\(modifier)\" in \(type) keybind. Valid modifiers: ctrl, option, cmd, shift"
        }
    }
}

public class ConfigManager {
    private static let defaultConfigContent = """
# ClipSlots Configuration

# Number of slots (1-10)
slots = 5

# Show daemon logs in terminal (true/false)
# Logs save/paste actions, startup info, errors, etc.
verbose = true

# Optional: auto-expire stale slots after this many hours. The daemon
# sweeps once per hour and clears any slot whose last-write time is
# older than the threshold. Locked slots are never expired.
# Leave the line commented out (or remove it) to disable expiry.
#
# expire_after_hours = 24

# Optional: confirm that a hotkey fired. Off by default.
#   "sound"  - short system sound on save/paste/append
#   "visual" - purple checkmark next to the pointer on save/append
#              (ClipSlots.app only; the CLI daemon has no UI)
#   "both"   - sound and checkmark
# Never fires from CLI commands (`clipslots save` / `paste`), only hotkeys.
#
# feedback = "sound"

# Keybind configuration
# Use {n} as placeholder for the slot number
#
# Available modifiers: ctrl, option, cmd, shift
# Available keys: 0-9, a-z, f1-f12
#
# Examples:
#   "ctrl+option+{n}"   → Ctrl+Option+1 for slot 1
#   "cmd+shift+{n}"     → Cmd+Shift+1 for slot 1
[keybinds]
save = "ctrl+option+{n}"
paste = "ctrl+{n}"

# Optional: append-mode hotkey. Appends the current clipboard text to
# slot N instead of overwriting it — useful for collecting snippets.
# Uncomment the two lines below (remove the leading "#") to enable.
#
# Skipped silently when the target slot is locked, the slot's current
# content is non-text, or the clipboard is non-text. Appending to an
# empty slot acts as a normal save. Rich-text slots collapse to plain
# text on append.
#
# append = "ctrl+option+shift+{n}"
# append_separator = "\\n"

# Optional: shortcut that opens the ClipSlots menubar app's popover.
# Only used by ClipSlots.app (the CLI ignores it). A single fixed combo,
# no {n}. Set to "" to disable.
#
# popover = "ctrl+option+v"
"""

    public static func load() throws -> Config {
        let configURL = Paths.configFile

        try Paths.ensureDirectoryExists(at: Paths.configDirectory)

        if !FileManager.default.fileExists(atPath: configURL.path) {
            try defaultConfigContent.write(to: configURL, atomically: true, encoding: .utf8)
            return Config.default
        }

        do {
            let tomlData = try Data(contentsOf: configURL)
            let config = try TOMLDecoder().decode(Config.self, from: tomlData)
            try config.validate()
            return config
        } catch let error as ConfigError {
            print("Warning: \(error.localizedDescription) Using defaults.")
            return Config.default
        } catch {
            print("Warning: Could not parse config: \(error.localizedDescription). Using defaults.")
            return Config.default
        }
    }

    /// Like `load()` but does not swallow parse/validation errors. Used by
    /// `config validate` so real problems surface with a non-zero exit.
    /// If the file doesn't exist, it's created with defaults (same as `load()`).
    public static func loadStrict() throws -> Config {
        let configURL = Paths.configFile

        try Paths.ensureDirectoryExists(at: Paths.configDirectory)

        if !FileManager.default.fileExists(atPath: configURL.path) {
            try defaultConfigContent.write(to: configURL, atomically: true, encoding: .utf8)
            return Config.default
        }

        let tomlData = try Data(contentsOf: configURL)
        let config = try TOMLDecoder().decode(Config.self, from: tomlData)
        try config.validate()
        return config
    }
}
