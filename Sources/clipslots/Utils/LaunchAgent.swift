import Foundation

class LaunchAgentManager {
    static let label = "com.clipslots.daemon"
    static let plistPath = Paths.launchAgentPlist

    static func resolveBinaryPath() -> String {
        let arg0 = ProcessInfo.processInfo.arguments[0]
        if arg0.hasPrefix("/") { return arg0 }
        let cwd = FileManager.default.currentDirectoryPath
        return (cwd as NSString).appendingPathComponent(arg0)
    }

    static func install() throws -> Bool {
        try Paths.ensureDirectoryExists(at: Paths.launchAgentDirectory)

        let binaryPath = resolveBinaryPath()
        let plist = generatePlist(binaryPath: binaryPath)
        try plist.write(to: plistPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    static func uninstall() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // May not be loaded
        }

        try? FileManager.default.removeItem(at: plistPath)
        return true
    }

    static func isRunning() -> (running: Bool, pid: Int?) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", label]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, nil)
        }

        guard process.terminationStatus == 0 else {
            return (false, nil)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("\"PID\""),
               let eqRange = trimmed.range(of: "=") {
                let afterEq = trimmed[eqRange.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let pid = Int(afterEq) {
                    return (true, pid)
                }
            }
        }

        return (true, nil)
    }

    private static func generatePlist(binaryPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>daemon</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(Paths.logFile.path)</string>
            <key>StandardErrorPath</key>
            <string>\(Paths.errorLogFile.path)</string>
        </dict>
        </plist>
        """
    }
}
