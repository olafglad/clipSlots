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

/// Hourly sweep that clears non-locked slots whose mtime exceeds the
/// configured threshold. `hoursThreshold == nil` keeps the sweep idle.
class ExpirySweeper {
    private var storage: SlotStorage
    private var hoursThreshold: Int?
    private let log: (String) -> Void
    private var timer: DispatchSourceTimer?
    private let interval: DispatchTimeInterval = .seconds(60 * 60)

    init(storage: SlotStorage, hoursThreshold: Int?, log: @escaping (String) -> Void) {
        self.storage = storage
        self.hoursThreshold = hoursThreshold
        self.log = log
    }

    func start() {
        rebuild()
    }

    func reload(storage: SlotStorage, hoursThreshold: Int?) {
        self.storage = storage
        self.hoursThreshold = hoursThreshold
        rebuild()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func rebuild() {
        timer?.cancel()
        timer = nil
        guard let hours = hoursThreshold, hours > 0 else {
            // Disabling resets the grace-period marker so the next enable
            // earns a fresh full grace period instead of reusing a stale
            // timestamp from a previous on-period.
            try? storage.clearExpiryEnabled()
            log("Expiry sweep disabled (expire_after_hours not set).")
            return
        }

        // First time we observe the feature enabled, stamp the moment so
        // the grace-period floor lives across daemon restarts. Idempotent
        // on subsequent rebuilds (e.g. user edits the hours value).
        let enabledAt: Date
        do {
            enabledAt = try storage.markExpiryEnabled()
        } catch {
            print("[\(DateFormatter.shortTime.string(from: Date()))] Could not persist expiry-enabled timestamp: \(error.localizedDescription)")
            enabledAt = Date()
        }

        log("Expiry sweep enabled: clearing non-locked slots older than \(hours)h, checking hourly.")
        let earliest = enabledAt.addingTimeInterval(TimeInterval(hours) * 3600)
        if earliest > Date() {
            let stampFormatter = ISO8601DateFormatter()
            log("  Grace period: existing slots will not be cleared before \(stampFormatter.string(from: earliest)).")
        }

        // Run once at startup so a daemon that just woke up doesn't wait
        // a full hour to clean up stale slots from earlier sessions. The
        // grace-period floor prevents this from being destructive on the
        // first enable.
        sweep()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.sweep() }
        t.resume()
        timer = t
    }

    private func sweep() {
        guard let hours = hoursThreshold, hours > 0 else { return }
        let thresholdSeconds = TimeInterval(hours) * 3600
        do {
            let cleared = try storage.clearExpired(
                olderThanSeconds: thresholdSeconds,
                enabledFloor: storage.expiryEnabledAt()
            )
            let now = Date()
            for entry in cleared {
                let age = relativeAge(from: entry.mtime, to: now)
                log("[\(DateFormatter.shortTime.string(from: now))] Expired slot \(entry.slot) (age \(age))")
            }
        } catch {
            print("[\(DateFormatter.shortTime.string(from: Date()))] Expiry sweep failed: \(error.localizedDescription)")
        }
    }

    private func relativeAge(from date: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h\(minutes % 60)m" }
        let days = hours / 24
        return "\(days)d\(hours % 24)h"
    }
}

class ConfigFileWatcher {
    private let configURL: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(configURL: URL, onChange: @escaping () -> Void) {
        self.configURL = configURL
        self.onChange = onChange
    }

    func start() {
        watch()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func watch() {
        source?.cancel()

        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else {
            // File may not exist yet — poll until it does
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.watch()
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Small delay — editors may write then rename in quick succession
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.onChange()
                // Re-watch: the inode likely changed after a save-and-replace
                self.watch()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }
}
