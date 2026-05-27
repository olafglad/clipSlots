import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show or edit configuration",
        discussion: """
            Examples:
              clipslots config             # show current values
              clipslots config edit        # open in $EDITOR
              clipslots config validate    # check for parse/schema errors
              clipslots config path        # print absolute path to config file
            """,
        subcommands: [Edit.self, Validate.self, Path.self]
    )

    // Hidden backward-compat flag: `clipslots config --edit` keeps working.
    @Flag(name: .shortAndLong, help: .hidden)
    var edit: Bool = false

    mutating func run() throws {
        if edit {
            var sub = Edit()
            try sub.run()
            return
        }
        try Self.showConfig()
    }

    static func showConfig() throws {
        let configPath = Paths.configFile.path

        if !FileManager.default.fileExists(atPath: configPath) {
            _ = try ConfigManager.load()
        }

        let config = try ConfigManager.load()
        let keyWidth = 13

        print(Style.sectionHeader("ClipSlots Configuration"))
        print(Style.keyValue("Config file:", configPath, keyWidth: keyWidth))
        print("")

        print(Style.sectionHeader("General"))
        print(Style.keyValue("Slots:", String(config.slots), keyWidth: keyWidth))
        print(Style.keyValue("Logging:", config.verbose ? "on" : "off", keyWidth: keyWidth))
        let expireDesc = config.expire_after_hours.map { "\($0)h" } ?? "off"
        print(Style.keyValue("Expire after:", expireDesc, keyWidth: keyWidth))
        print(Style.keyValue("Feedback:", config.feedback, keyWidth: keyWidth))
        print("")

        print(Style.sectionHeader("Keybinds"))
        print(Style.keyValue("Save:", config.keybinds.save, keyWidth: keyWidth))
        print(Style.keyValue("Paste:", config.keybinds.paste, keyWidth: keyWidth))
        if config.keybinds.append.isEmpty {
            print(Style.keyValue("Append:", "off", keyWidth: keyWidth))
            print("")
            print("To enable append mode, uncomment these lines under")
            print("[keybinds] in the config file (run 'clipslots config edit'):")
            print("  append = \"ctrl+option+shift+{n}\"")
            print("  append_separator = \"\\n\"")
        } else {
            print(Style.keyValue("Append:", config.keybinds.append, keyWidth: keyWidth))
            let sepDesc = config.keybinds.append_separator
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
            print(Style.keyValue("Separator:", "\"\(sepDesc)\"", keyWidth: keyWidth))
        }
        print("")
        print("Run 'clipslots config edit' to open in editor.")
    }

    // MARK: - Subcommands

    struct Edit: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Open the config file in $EDITOR",
            discussion: """
                Example:
                  clipslots config edit

                Falls back to macOS `open -t` when $EDITOR is unset.
                """
        )

        mutating func run() throws {
            let configPath = Paths.configFile.path

            // Ensure the file exists before launching the editor.
            if !FileManager.default.fileExists(atPath: configPath) {
                _ = try ConfigManager.load()
            }

            openInEditor(configPath)
        }

        private func openInEditor(_ path: String) {
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

    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check that the config file parses and validates",
            discussion: """
                Example:
                  clipslots config validate

                Exits 0 with "Config OK" on success, or 1 with a specific
                error message on parse/schema failure.
                """
        )

        mutating func run() throws {
            do {
                _ = try ConfigManager.loadStrict()
                print("Config OK: \(Paths.configFile.path)")
            } catch let error as ConfigError {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                FileHandle.standardError.write(Data("File: \(Paths.configFile.path)\n".utf8))
                throw ExitCode(1)
            } catch {
                FileHandle.standardError.write(Data("Could not parse config: \(error.localizedDescription)\n".utf8))
                FileHandle.standardError.write(Data("File: \(Paths.configFile.path)\n".utf8))
                throw ExitCode(1)
            }
        }
    }

    struct Path: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print absolute path to the config file",
            discussion: """
                Example:
                  cd "$(dirname "$(clipslots config path)")"
                """
        )

        mutating func run() throws {
            print(Paths.configFile.path)
        }
    }
}
