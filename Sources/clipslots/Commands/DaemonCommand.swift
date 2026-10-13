import ArgumentParser
import ClipSlotsCore
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

        var config = try ConfigManager.load()

        func log(_ message: String) {
            guard config.verbose else { return }
            print(message)
        }

        log("ClipSlots daemon starting at \(ISO8601DateFormatter().string(from: Date()))")
        log("Config loaded: \(config.slots) slots")
        log("Save keybind: \(config.keybinds.save)")
        log("Paste keybind: \(config.keybinds.paste)")

        // Check Accessibility permission (required for CGEvent posting)
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        if !trusted {
            print("WARNING: Accessibility permission not granted.")
            print("Hotkey save/paste will not work without it.")
            print("Grant access in System Settings > Privacy & Security > Accessibility")
            print("(called \"Device Control and Data Access\" on newer macOS)")
        }

        var storage = try SlotStorage(slotCount: config.slots)
        let clipboard = Clipboard()
        let hotkeyManager = HotkeyManager(config: config, storage: storage, clipboard: clipboard)

        hotkeyManager.registerHotkeys()

        // Expiry sweep: a hourly DispatchSourceTimer that clears stale
        // (non-locked) slots when `expire_after_hours` is configured.
        // Held in a box so the config-reload closure can swap storage
        // references without losing the timer handle.
        let expirySweeper = ExpirySweeper(storage: storage, hoursThreshold: config.expire_after_hours, log: log)
        expirySweeper.start()

        // Watch config file for changes
        let configWatcher = ConfigFileWatcher(configURL: Paths.configFile) {
            do {
                let newConfig = try ConfigManager.load()
                try newConfig.validate()
                let newStorage = try SlotStorage(slotCount: newConfig.slots)
                config = newConfig
                storage = newStorage
                hotkeyManager.reload(config: newConfig, storage: newStorage)
                expirySweeper.reload(storage: newStorage, hoursThreshold: newConfig.expire_after_hours)
            } catch {
                print("[\(DateFormatter.shortTime.string(from: Date()))] Config reload failed: \(error.localizedDescription)")
            }
        }
        configWatcher.start()

        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigintSource.setEventHandler {
            print("\nReceived SIGINT, shutting down...")
            configWatcher.stop()
            expirySweeper.stop()
            hotkeyManager.unregisterAll()
            Darwin.exit(0)
        }
        sigintSource.resume()

        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        signal(SIGTERM, SIG_IGN)
        sigtermSource.setEventHandler {
            print("\nReceived SIGTERM, shutting down...")
            configWatcher.stop()
            expirySweeper.stop()
            hotkeyManager.unregisterAll()
            Darwin.exit(0)
        }
        sigtermSource.resume()

        log("Daemon ready. Listening for hotkeys...")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
