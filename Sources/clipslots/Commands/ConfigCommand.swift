import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Open configuration file in editor"
    )

    mutating func run() throws {
        let configPath = Paths.configFile.path

        if !FileManager.default.fileExists(atPath: configPath) {
            _ = try ConfigManager.load()
        }

        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, configPath]
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            print("Editor exited with status: \(process.terminationStatus)")
        }
    }
}
