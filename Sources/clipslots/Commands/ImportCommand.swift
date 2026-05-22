import ArgumentParser
import Foundation

struct ImportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import slots from a tar archive"
    )

    @Argument(help: "Source archive path")
    var path: String

    @Flag(name: .long, help: "Overwrite existing non-empty slots")
    var force: Bool = false

    mutating func run() throws {
        let fm = FileManager.default

        let srcURL: URL = {
            if (path as NSString).isAbsolutePath {
                return URL(fileURLWithPath: path)
            }
            let cwd = fm.currentDirectoryPath
            return URL(fileURLWithPath: cwd).appendingPathComponent(path)
        }()

        guard fm.isReadableFile(atPath: srcURL.path) else {
            throw ValidationError("Archive not found or not readable: \(srcURL.path)")
        }

        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        // Safety check: refuse if any slot is non-empty unless --force
        let nonEmptyCount = (1...config.slots).filter { !storage.isSlotEmpty($0) }.count
        if nonEmptyCount > 0 && !force {
            throw ValidationError("Refusing to overwrite \(nonEmptyCount) non-empty slot(s). Re-run with --force to replace.")
        }

        // Staging dir
        let pid = ProcessInfo.processInfo.processIdentifier
        let stagingDir = Paths.dataDirectory.appendingPathComponent(".import_tmp_\(pid)")
        if fm.fileExists(atPath: stagingDir.path) {
            try fm.removeItem(at: stagingDir)
        }
        try Paths.ensureDirectoryExists(at: stagingDir)

        defer {
            try? fm.removeItem(at: stagingDir)
        }

        // Extract: tar -xf <archive> -C <staging>
        let extract = Process()
        extract.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extract.arguments = [
            "-xf", srcURL.path,
            "-C", stagingDir.path
        ]
        let errPipe = Pipe()
        extract.standardError = errPipe
        try extract.run()
        extract.waitUntilExit()

        if extract.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw ValidationError("tar extract failed (exit \(extract.terminationStatus)): \(errStr)")
        }

        // Validate extracted layout
        let extractedSlots = stagingDir.appendingPathComponent("slots")
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: extractedSlots.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("Archive does not contain a top-level 'slots/' directory.")
        }

        let contents = (try? fm.contentsOfDirectory(at: extractedSlots, includingPropertiesForKeys: nil)) ?? []
        let hasNumericDir = contents.contains { url in
            var d: ObjCBool = false
            let exists = fm.fileExists(atPath: url.path, isDirectory: &d)
            return exists && d.boolValue && Int(url.lastPathComponent) != nil
        }
        let hasManifest = contents.contains { $0.lastPathComponent == "manifest.json" }
        guard hasNumericDir || hasManifest else {
            throw ValidationError("Archive 'slots/' directory has no recognizable slot data.")
        }

        // Atomic-ish swap: rename current slots aside, move new in, then remove backup.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let backupDir = Paths.dataDirectory.appendingPathComponent("slots.preimport_\(stamp)")

        let currentSlots = Paths.slotsDirectory
        let currentExists = fm.fileExists(atPath: currentSlots.path)

        if currentExists {
            try fm.moveItem(at: currentSlots, to: backupDir)
        }

        do {
            try fm.moveItem(at: extractedSlots, to: currentSlots)
        } catch {
            // Restore backup on failure
            if currentExists {
                try? fm.moveItem(at: backupDir, to: currentSlots)
            }
            throw error
        }

        // Remove backup on success
        if currentExists {
            try? fm.removeItem(at: backupDir)
        }

        // Refresh manifest from on-disk state
        let newStorage = try SlotStorage(slotCount: config.slots)
        try newStorage.refreshManifest()
        let count = newStorage.getManifest()?.entries.count ?? 0
        print("Imported \(count) slot\(count == 1 ? "" : "s") from \(srcURL.path)")
    }
}
