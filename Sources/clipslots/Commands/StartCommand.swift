import ArgumentParser
import ClipSlotsCore
import Foundation

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start the ClipSlots daemon"
    )

    mutating func run() throws {
        if MenubarApp.isRunning {
            print(MenubarApp.takeoverMessage)
            return
        }

        let (running, pid) = LaunchAgentManager.isRunning()
        if running {
            print("ClipSlots daemon already running (PID: \(pid.map(String.init) ?? "unknown"))")
            return
        }

        print("Starting ClipSlots daemon...")
        if try LaunchAgentManager.install() {
            print("ClipSlots daemon started successfully")
            print("Logs: \(Paths.logFile.path)")
        } else {
            throw ValidationError("Failed to start daemon. Check logs at \(Paths.errorLogFile.path)")
        }
    }
}
