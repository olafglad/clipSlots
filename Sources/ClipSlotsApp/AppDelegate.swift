import AppKit
import ClipSlotsCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: AppEngine!
    private var model: SlotsModel!
    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private var onboarding: OnboardingWindowController?
    private var keyMonitor: Any?
    /// The app that was frontmost before the panel opened. The panel never
    /// activates ClipSlots, so this only matters when something else did
    /// (e.g. the setup window) and focus has to be handed back for Paste.
    private var previousApp: NSRunningApplication?

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = MenubarApp.runningInstance() {
            print("ClipSlots.app is already running (PID \(other.processIdentifier)); exiting.")
            NSApp.terminate(nil)
            return
        }

        setbuf(stdout, nil)
        Theme.registerFonts()

        do {
            engine = try AppEngine()
        } catch {
            let alert = NSAlert()
            alert.messageText = "ClipSlots couldn't start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        model = SlotsModel(engine: engine, version: Self.version)
        model.closePopover = { [weak self] in self?.closePanel() }
        model.pasteIntoPreviousApp = { [weak self] n in self?.paste(slot: n) }
        model.showOnboarding = { [weak self] in self?.showOnboarding() }

        engine.onConfigReload = { [weak self] in self?.model.reload() }
        engine.onPopoverHotkey = { [weak self] in self?.togglePanel() }
        engine.start()

        setUpStatusItem()
        setUpPanel()
        setUpKeyMonitor()

        if !AXIsProcessTrusted() {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    // MARK: - Status item & panel

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = MenubarIcon.make()
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "ClipSlots (\(KeybindText.pretty(engine.config.keybinds.popover, slots: 1)))"
    }

    private func setUpPanel() {
        var controller: PanelController!
        controller = PanelController(rootView: PanelRootView(model: model) { size in
            controller?.contentSizeChanged(size)
        })
        controller.onHide = { [weak self] in
            self?.model.dragSource = nil
            self?.model.dropTarget = nil
            self?.model.peekSlot = nil
        }
        model.panelDragChanged = { controller?.dragChanged() }
        model.panelDragEnded = { controller?.dragEnded() }
        model.resetPanelPosition = { [weak self] in
            controller?.resetPosition()
            self?.closePanel()
            self?.showPanel()
        }
        panel = controller
    }

    @objc private func statusItemClicked() {
        // The click itself already hid the panel (it lost focus); don't reopen.
        if panel.justHid { return }
        togglePanel()
    }

    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        model.reload()
        model.peekSlot = nil
        model.filter = ""
        model.dragSource = nil
        model.dropTarget = nil

        panel.show(below: statusItem.button)
        NotificationCenter.default.post(name: .clipSlotsFocusFilter, object: nil)
    }

    private func closePanel() {
        panel.hide()
    }

    private func paste(slot n: Int) {
        closePanel()
        // Normally the previous app is still frontmost (the panel doesn't
        // activate us). If ClipSlots got activated meanwhile, hand focus back.
        if NSApp.isActive {
            previousApp?.activate(options: [])
        }
        // Give the target window a moment to become key before Cmd+V lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.engine.hotkeys.paste(slot: n)
        }
    }

    private func showOnboarding() {
        guard !AXIsProcessTrusted() else {
            model.refreshAccessibility()
            return
        }
        closePanel()
        if onboarding == nil {
            onboarding = OnboardingWindowController(model: model) { [weak self] in
                // Granted: get out of the way and show what the user came for.
                self?.showPanel()
            }
        }
        onboarding?.present()
    }

    // MARK: - Keyboard

    /// Popover keys, in the spirit of the CLI: ↑↓ move, ⏎ copy, ⌘⏎ paste,
    /// 1–9 jump, space peek, ⌘Z undo, ⌘F filter, esc back/clear/close.
    /// Digits and space only act while the filter is empty, so typing a
    /// filter is never hijacked.
    private func setUpKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.panel.isVisible, event.window === self.panel.panel else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if event.keyCode == 53 { // esc
            if model.peekSlot != nil {
                model.peekSlot = nil
            } else if !model.filter.isEmpty {
                model.filter = ""
            } else {
                closePanel()
            }
            return true
        }

        if mods == .command && chars == "q" {
            NSApp.terminate(nil)
            return true
        }

        // Peek: ⏎ copies, ⌘⏎ pastes, unless the label field is being edited.
        if let n = model.peekSlot {
            guard !model.labelFieldFocused else { return false }
            if event.keyCode == 36 || event.keyCode == 76 {
                if mods == .command { model.paste(n) } else if mods.isEmpty { model.copy(n) }
                return true
            }
            return false
        }

        switch (event.keyCode, mods) {
        case (126, []): model.moveSelection(by: -1); return true // ↑
        case (125, []): model.moveSelection(by: 1); return true  // ↓
        case (36, []), (76, []):                                  // ⏎
            if model.slot(model.selected)?.isEmpty == false { model.copy(model.selected) }
            return true
        case (36, .command), (76, .command):                      // ⌘⏎
            model.paste(model.selected)
            return true
        default:
            break
        }

        if mods == .command && chars == "z" {
            model.undo(model.selected)
            return true
        }
        if mods == .command && chars == "f" {
            NotificationCenter.default.post(name: .clipSlotsFocusFilter, object: nil)
            return true
        }

        if mods.isEmpty && model.filter.isEmpty {
            if let digit = Int(chars), chars.count == 1 {
                let n = digit == 0 ? 10 : digit
                if n <= model.slotCount { model.select(n) }
                return true
            }
            if event.keyCode == 49, model.slot(model.selected)?.isEmpty == false { // space
                model.peekSlot = model.selected
                return true
            }
        }
        return false
    }
}
