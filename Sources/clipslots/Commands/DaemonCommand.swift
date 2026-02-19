import ArgumentParser
import AppKit
import ApplicationServices
import Foundation

struct Daemon: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run as daemon (internal use)",
        shouldDisplay: false
    )

    mutating func run() throws {
        setbuf(stdout, nil)

        print("ClipSlots daemon starting at \(ISO8601DateFormatter().string(from: Date()))")

        let config = try ConfigManager.load()
        print("Config loaded: \(config.slots) slots")
        print("Save keybind: \(config.keybinds.save)")
        print("Paste keybind: \(config.keybinds.paste)")

        // Check Accessibility permission (required for CGEvent posting)
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        if !trusted {
            print("WARNING: Accessibility permission not granted.")
            print("Hotkey save/paste will not work without it.")
            print("Grant access in System Settings > Privacy & Security > Accessibility")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        let clipboard = Clipboard()
        let hotkeyManager = HotkeyManager(config: config, storage: storage, clipboard: clipboard)

        hotkeyManager.registerHotkeys()

        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigintSource.setEventHandler {
            print("\nReceived SIGINT, shutting down...")
            hotkeyManager.unregisterAll()
            Darwin.exit(0)
        }
        sigintSource.resume()

        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        signal(SIGTERM, SIG_IGN)
        sigtermSource.setEventHandler {
            print("\nReceived SIGTERM, shutting down...")
            hotkeyManager.unregisterAll()
            Darwin.exit(0)
        }
        sigtermSource.resume()

        print("Daemon ready. Listening for hotkeys...")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
