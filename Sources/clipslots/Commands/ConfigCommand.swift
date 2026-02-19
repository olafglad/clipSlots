import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show or edit configuration"
    )

    @Flag(name: .shortAndLong, help: "Open config file in editor")
    var edit = false

    mutating func run() throws {
        let configPath = Paths.configFile.path

        if !FileManager.default.fileExists(atPath: configPath) {
            _ = try ConfigManager.load()
        }

        if edit {
            openInEditor(configPath)
        } else {
            let config = try ConfigManager.load()
            print("ClipSlots Configuration")
            print("───────────────────────")
            print("Config file: \(configPath)")
            print("")
            print("Slots:       \(config.slots)")
            print("Logging:     \(config.verbose ? "on" : "off")")
            print("")
            print("Keybinds:")
            print("  Save:      \(config.keybinds.save)")
            print("  Paste:     \(config.keybinds.paste)")
            print("")
            print("Run 'clipslots config --edit' to open in editor.")
        }
    }

    private func openInEditor(_ path: String) {
        // Try $EDITOR first, then fall back to macOS `open -t`
        let editor = ProcessInfo.processInfo.environment["EDITOR"]

        let process = Process()
        if let editor = editor, !editor.isEmpty {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editor, path]
            process.standardInput = FileHandle.standardInput
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-t", path]
        }

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                print("Editor exited with status: \(process.terminationStatus)")
            }
        } catch {
            print("Could not open editor: \(error.localizedDescription)")
            print("Edit manually: \(path)")
        }
    }
}
