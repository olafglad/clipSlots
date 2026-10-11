import Foundation

public struct Paths {
    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static var configDirectory: URL {
        homeDirectory.appendingPathComponent(".config/clipslots")
    }

    public static var configFile: URL {
        configDirectory.appendingPathComponent("config.toml")
    }

    public static var dataDirectory: URL {
        homeDirectory.appendingPathComponent(".local/share/clipslots")
    }

    public static var slotsFile: URL {
        dataDirectory.appendingPathComponent("slots.json")
    }

    public static var slotsDirectory: URL {
        dataDirectory.appendingPathComponent("slots")
    }

    public static var manifestFile: URL {
        slotsDirectory.appendingPathComponent("manifest.json")
    }

    public static var labelsFile: URL {
        slotsDirectory.appendingPathComponent("labels.json")
    }

    public static var locksFile: URL {
        slotsDirectory.appendingPathComponent("locks.json")
    }

    public static var expiryStateFile: URL {
        slotsDirectory.appendingPathComponent("expiry_state.json")
    }

    public static func slotDirectory(_ slot: Int) -> URL {
        slotsDirectory.appendingPathComponent(String(slot))
    }

    /// Per-slot previous-content snapshot for `undo`. Lives outside
    /// `slotDirectory(_:)` because `SlotStorage.setSlot` wipes the whole
    /// slot dir on every write.
    public static var prevSnapshotsDirectory: URL {
        slotsDirectory.appendingPathComponent(".prev")
    }

    public static func slotPrevDirectory(_ slot: Int) -> URL {
        prevSnapshotsDirectory.appendingPathComponent(String(slot))
    }

    public static func slotItemDirectory(_ slot: Int, itemIndex: Int) -> URL {
        slotDirectory(slot).appendingPathComponent("item_\(itemIndex)")
    }

    public static var launchAgentDirectory: URL {
        homeDirectory.appendingPathComponent("Library/LaunchAgents")
    }

    public static var launchAgentPlist: URL {
        launchAgentDirectory.appendingPathComponent("com.clipslots.daemon.plist")
    }

    public static var binaryPath: String {
        return "/usr/local/bin/clipslots"
    }

    public static var logFile: URL {
        URL(fileURLWithPath: "/tmp/clipslots.log")
    }

    public static var errorLogFile: URL {
        URL(fileURLWithPath: "/tmp/clipslots.err")
    }

    public static func ensureDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public static func ensureAllDirectoriesExist() throws {
        try ensureDirectoryExists(at: configDirectory)
        try ensureDirectoryExists(at: dataDirectory)
        try ensureDirectoryExists(at: launchAgentDirectory)
    }
}
