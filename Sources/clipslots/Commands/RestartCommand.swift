import ArgumentParser
import Foundation

struct Restart: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Restart the ClipSlots daemon"
    )

    mutating func run() throws {
        print("Restarting ClipSlots daemon...")

        let (running, _) = LaunchAgentManager.isRunning()
        if running {
            _ = LaunchAgentManager.uninstall()
            Thread.sleep(forTimeInterval: 1.0)
        }

        if try LaunchAgentManager.install() {
            print("ClipSlots daemon restarted successfully")
        } else {
            throw ValidationError("Failed to restart daemon")
        }
    }
}
