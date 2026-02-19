import Foundation
import TOMLDecoder

struct Config: Codable {
    var slots: Int = 5
    var verbose: Bool = true
    var keybinds: Keybinds = Keybinds()

    struct Keybinds: Codable {
        var save: String = "ctrl+option+{n}"
        var paste: String = "ctrl+{n}"
    }

    static var `default`: Config { Config() }

    func validate() throws {
        guard (1...10).contains(slots) else {
            throw ConfigError.invalidSlotCount(slots)
        }
        try validateKeybindPattern(keybinds.save, type: "save")
        try validateKeybindPattern(keybinds.paste, type: "paste")
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

    func expandKeybind(_ pattern: String, slot: Int) -> String {
        pattern.replacingOccurrences(of: "{n}", with: String(slot))
    }
}

enum ConfigError: LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case invalidSlotCount(Int)
    case missingPlaceholder(type: String, pattern: String)
    case invalidKeybindFormat(type: String, pattern: String)
    case invalidModifier(modifier: String, type: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Config file not found. Creating default configuration."
        case .invalidFormat(let error):
            return "Config error in ~/.config/clipslots/config.toml: \(error). Using defaults."
        case .invalidSlotCount(let count):
            return "Invalid slot count: \(count). Must be between 1 and 10."
        case .missingPlaceholder(let type, let pattern):
            return "Invalid keybind for \(type): \"\(pattern)\" missing {n} placeholder."
        case .invalidKeybindFormat(let type, let pattern):
            return "Invalid keybind format for \(type): \"\(pattern)\". Expected format: modifier+modifier+{n}"
        case .invalidModifier(let modifier, let type):
            return "Invalid modifier \"\(modifier)\" in \(type) keybind. Valid modifiers: ctrl, option, cmd, shift"
        }
    }
}

class ConfigManager {
    private static let defaultConfigContent = """
# ClipSlots Configuration

# Number of slots (1-10)
slots = 5

# Show daemon logs in terminal (true/false)
verbose = true

# Keybind configuration
# Modifiers: ctrl, option, cmd, shift
# Keys: 1-9, 0, a-z, f1-f12
# Use {n} as placeholder for slot number
[keybinds]
save = "ctrl+option+{n}"
paste = "ctrl+{n}"
"""

    static func load() throws -> Config {
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
}
