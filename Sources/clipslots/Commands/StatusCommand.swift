import ApplicationServices
import ArgumentParser
import Foundation

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show daemon status and configuration"
    )

    mutating func run() throws {
        let config = try ConfigManager.load()
        let clipboard = Clipboard()
        let (running, pid) = LaunchAgentManager.isRunning()

        print("ClipSlots Status")
        print("────────────────")

        if running {
            print("Daemon:      Running (PID: \(pid.map(String.init) ?? "unknown"))")
        } else {
            print("Daemon:      Not running")
        }

        let accessible = AXIsProcessTrusted()
        print("Accessible:  \(accessible ? "Yes" : "No (hotkeys won't work)")")
        print("Pasteboard:  \(clipboard.permissionStatus.description)")
        print("Slots:       \(config.slots)")
        print("Logging:     \(config.verbose ? "on" : "off") (change in 'clipslots config --edit')")
        print("")
        print("Keybinds:")
        print("  Save:      \(config.keybinds.save)")
        print("  Paste:     \(config.keybinds.paste)")
    }
}
