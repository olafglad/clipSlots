import AppKit
import ClipSlotsCore
import HotKey

/// The hotkey/daemon half of the app: the same engine `clipslots daemon`
/// runs (slot hotkeys, expiry sweep, config hot-reload), plus the popover
/// shortcut. While the app runs it owns the hotkeys; the CLI's LaunchAgent
/// daemon is stopped on launch so the two never register the same combos.
final class AppEngine {
    private(set) var config: Config
    private(set) var storage: SlotStorage
    let clipboard = Clipboard()
    let hotkeys: HotkeyManager

    private var popoverHotkey: HotKey?
    private let sweeper: ExpirySweeper
    private var configWatcher: ConfigFileWatcher?

    /// Called on the main queue after config.toml changes and reloads.
    var onConfigReload: (() -> Void)?
    /// Called when the popover shortcut fires.
    var onPopoverHotkey: (() -> Void)?

    init() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)
        self.config = config
        self.storage = storage
        self.hotkeys = HotkeyManager(config: config, storage: storage, clipboard: clipboard)
        self.sweeper = ExpirySweeper(storage: storage, hoursThreshold: config.expire_after_hours) { message in
            guard config.verbose else { return }
            print(message)
        }
    }

    func start() {
        takeOverFromCLIDaemon()
        hotkeys.registerHotkeys()
        registerPopoverHotkey()
        sweeper.start()

        let watcher = ConfigFileWatcher(configURL: Paths.configFile) { [weak self] in
            self?.reloadConfig()
        }
        watcher.start()
        configWatcher = watcher
    }

    func stop() {
        configWatcher?.stop()
        sweeper.stop()
        hotkeys.unregisterAll()
        popoverHotkey = nil
    }

    private func reloadConfig() {
        do {
            let newConfig = try ConfigManager.load()
            try newConfig.validate()
            let newStorage = try SlotStorage(slotCount: newConfig.slots)
            config = newConfig
            storage = newStorage
            hotkeys.reload(config: newConfig, storage: newStorage)
            sweeper.reload(storage: newStorage, hoursThreshold: newConfig.expire_after_hours)
            registerPopoverHotkey()
            onConfigReload?()
        } catch {
            print("Config reload failed: \(error.localizedDescription)")
        }
    }

    private func registerPopoverHotkey() {
        popoverHotkey = nil
        let combo = config.keybinds.popover
        guard !combo.isEmpty, let (key, modifiers) = HotkeyManager.parseCombo(combo) else { return }
        let hotkey = HotKey(key: key, modifiers: modifiers)
        hotkey.keyDownHandler = { [weak self] in self?.onPopoverHotkey?() }
        popoverHotkey = hotkey
    }

    /// Stops the CLI's LaunchAgent daemon if it is loaded. Both processes
    /// would otherwise try to own the same global hotkeys. `clipslots start`
    /// refuses to run while the app is up, so this only happens once.
    private func takeOverFromCLIDaemon() {
        guard LaunchAgentManager.isRunning().running else { return }
        _ = LaunchAgentManager.uninstall()
        print("Stopped the CLI daemon; ClipSlots.app now handles the hotkeys.")
    }
}
