import ArgumentParser
import Foundation

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export all slots to a tar archive",
        discussion: """
            Example:
              clipslots export ~/clipslots-backup.tar
            """
    )

    @Argument(help: "Destination archive path (e.g. slots.tar)")
    var path: String

    mutating func run() throws {
        let fm = FileManager.default

        // Resolve destination against CWD if relative
        let destURL: URL = {
            if (path as NSString).isAbsolutePath {
                return URL(fileURLWithPath: path)
            }
            let cwd = fm.currentDirectoryPath
            return URL(fileURLWithPath: cwd).appendingPathComponent(path)
        }()

        let parentDir = destURL.deletingLastPathComponent()
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: parentDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("Destination directory does not exist: \(parentDir.path)")
        }

        if fm.fileExists(atPath: destURL.path) {
            throw ValidationError("Destination already exists: \(destURL.path). Remove it or choose a different path.")
        }

        guard fm.fileExists(atPath: Paths.slotsDirectory.path) else {
            throw ValidationError("No slots directory found at \(Paths.slotsDirectory.path)")
        }

        // Ensure manifest is fresh before archiving
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        // tar -cf <dest> -C <dataDirectory> slots
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "-cf", destURL.path,
            "-C", Paths.dataDirectory.path,
            "slots"
        ]
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw ValidationError("tar failed (exit \(process.terminationStatus)): \(errStr)")
        }

        let count = storage.getManifest()?.entries.count ?? 0
        print("Exported \(count) slot\(count == 1 ? "" : "s") to \(destURL.path)")
    }
}
