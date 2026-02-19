import Foundation

struct Paths {
    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var configDirectory: URL {
        homeDirectory.appendingPathComponent(".config/clipslots")
    }

    static var configFile: URL {
        configDirectory.appendingPathComponent("config.toml")
    }

    static var dataDirectory: URL {
        homeDirectory.appendingPathComponent(".local/share/clipslots")
    }

    static var slotsFile: URL {
        dataDirectory.appendingPathComponent("slots.json")
    }

    static var launchAgentDirectory: URL {
        homeDirectory.appendingPathComponent("Library/LaunchAgents")
    }

    static var launchAgentPlist: URL {
        launchAgentDirectory.appendingPathComponent("com.clipslots.daemon.plist")
    }

    static var binaryPath: String {
        #if arch(arm64)
        return "/opt/homebrew/bin/clipslots"
        #else
        return "/usr/local/bin/clipslots"
        #endif
    }

    static var logFile: URL {
        URL(fileURLWithPath: "/tmp/clipslots.log")
    }

    static var errorLogFile: URL {
        URL(fileURLWithPath: "/tmp/clipslots.err")
    }

    static func ensureDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    static func ensureAllDirectoriesExist() throws {
        try ensureDirectoryExists(at: configDirectory)
        try ensureDirectoryExists(at: dataDirectory)
        try ensureDirectoryExists(at: launchAgentDirectory)
    }
}
