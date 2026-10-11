import AppKit
import ClipSlotsCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var engine: AppEngine!
    private var model: SlotsModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var onboarding: OnboardingWindowController?
    private var keyMonitor: Any?
    /// The app that was frontmost before the popover opened; Paste sends
    /// Cmd+V back to it.
    private var previousApp: NSRunningApplication?

    private static let backgroundViewID = NSUserInterfaceItemIdentifier("clipslots.popover.background")

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
        model.closePopover = { [weak self] in self?.closePopover() }
        model.pasteIntoPreviousApp = { [weak self] n in self?.paste(slot: n) }
        model.showOnboarding = { [weak self] in self?.showOnboarding() }

        engine.onConfigReload = { [weak self] in self?.model.reload() }
        engine.onPopoverHotkey = { [weak self] in self?.togglePopover() }
        engine.start()

        setUpStatusItem()
        setUpPopover()
        setUpKeyMonitor()

        if !AXIsProcessTrusted() {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    // MARK: - Status item & popover

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = MenubarIcon.make()
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "ClipSlots (\(KeybindText.pretty(engine.config.keybinds.popover, slots: 1)))"
    }

    private func setUpPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self
        let hosting = NSHostingController(rootView: PopoverView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    @objc private func statusItemClicked() {
        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        model.reload()
        model.peekSlot = nil
        model.filter = ""
        model.dragSource = nil
        model.dropTarget = nil

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        paintPopoverBackground()
        popover.contentViewController?.view.window?.makeKey()
        NotificationCenter.default.post(name: .clipSlotsFocusFilter, object: nil)
    }

    /// Closes the popover and hands focus back to the app the user came
    /// from, so a ⌘V right after Copy lands there. Skipped while the setup
    /// window is open (hiding would take it down too).
    private func closePopover() {
        if popover.isShown { popover.performClose(nil) }
        if onboarding?.window?.isVisible != true {
            NSApp.hide(nil)
        }
    }

    /// NSPopover draws its own material (arrow included). Slip a solid
    /// brand-colored view under the content so popover and arrow match the
    /// mockup's #1E1430 instead of the system's translucent gray.
    private func paintPopoverBackground() {
        guard let frameView = popover.contentViewController?.view.window?.contentView?.superview,
              !frameView.subviews.contains(where: { $0.identifier == Self.backgroundViewID }) else { return }
        let background = NSView(frame: frameView.bounds)
        background.identifier = Self.backgroundViewID
        background.wantsLayer = true
        background.layer?.backgroundColor = Theme.backgroundNS.cgColor
        background.autoresizingMask = [.width, .height]
        frameView.addSubview(background, positioned: .below, relativeTo: nil)
    }

    func popoverDidClose(_ notification: Notification) {
        model.dragSource = nil
        model.dropTarget = nil
        model.peekSlot = nil
    }

    private func paste(slot n: Int) {
        closePopover()
        previousApp?.activate(options: [])
        // Give the target app a moment to become key before Cmd+V lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.engine.hotkeys.paste(slot: n)
        }
    }

    private func showOnboarding() {
        if popover.isShown { popover.performClose(nil) }
        if onboarding == nil {
            onboarding = OnboardingWindowController(model: model)
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
            guard let self = self, self.popover.isShown,
                  event.window == self.popover.contentViewController?.view.window else { return event }
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
                closePopover()
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
