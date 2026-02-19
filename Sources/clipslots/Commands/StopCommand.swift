import ArgumentParser
import Foundation

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop the ClipSlots daemon"
    )

    mutating func run() throws {
        let (running, _) = LaunchAgentManager.isRunning()
        if !running {
            print("ClipSlots daemon is not running")
            return
        }

        if LaunchAgentManager.uninstall() {
            print("ClipSlots daemon stopped")
        } else {
            throw ValidationError("Failed to stop daemon")
        }
    }
}
