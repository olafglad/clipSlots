import ArgumentParser
import ClipSlotsCore
import Foundation

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop the ClipSlots daemon"
    )

    mutating func run() throws {
        let (running, _) = LaunchAgentManager.isRunning()
        if !running {
            if MenubarApp.isRunning {
                print("The CLI daemon is not running; ClipSlots.app handles the hotkeys.")
                print("Quit it from the menubar icon to stop them.")
                return
            }
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
