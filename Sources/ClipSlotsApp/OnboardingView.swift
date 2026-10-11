import AppKit
import ApplicationServices
import SwiftUI

/// First-launch setup: one permission. Polls `AXIsProcessTrusted()` so the
/// screen flips to "granted" on its own once the user toggles ClipSlots on.
struct OnboardingView: View {
    @ObservedObject var model: SlotsModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                if let mascot = Mascot.image {
                    Image(nsImage: mascot)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(.bottom, -14)
                        .accessibilityLabel("ClipSlots octopus mascot holding clipboards")
                }
                Text(model.accessibilityGranted ? "all set" : "\(model.slotCount) slots, ready to fill")
                    .font(Theme.mono(18, .bold))
                    .padding(.top, 4)
                Text(model.accessibilityGranted
                     ? "Press \(KeybindText.pretty(model.keybinds.popover, slots: 1)) anytime, or click the clipboard icon in the menubar."
                     : "One permission and you're set. ClipSlots needs Accessibility so \(KeybindText.pretty(model.keybinds.paste, slots: model.slotCount)) can paste straight into the app you're in.")
                    .font(Theme.mono(12.5))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)

            SectionHeader(title: "Setup", trailing: model.accessibilityGranted ? "2 of 2" : "1 of 2")
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

            VStack(spacing: 8) {
                stepRow(done: true, title: "hotkeys engine running", trailing: "done")
                accessibilityStep
                loginRow
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 14)

            Divider().overlay(Theme.border)
            HStack {
                Text("CLI still works: ").foregroundColor(Theme.textSecondary)
                    + Text("clipslots list").foregroundColor(Theme.accentLight)
                Spacer()
                if model.accessibilityGranted {
                    ActionButton(title: "Done", symbol: "checkmark", primary: true, action: onDone)
                } else {
                    Link("docs", destination: URL(string: "https://clipslots.dev/docs/")!)
                        .foregroundColor(Theme.accentLight)
                }
            }
            .font(Theme.mono(11))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 400)
        .background(Theme.background)
        .foregroundColor(Theme.text)
        .environment(\.colorScheme, .dark)
    }

    private func stepRow(done: Bool, title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Text(done ? "●" : "○")
                .font(Theme.mono(14))
                .foregroundColor(done ? Theme.mint : Theme.accentLighter)
            Text(title).font(Theme.mono(12.5))
            Spacer()
            Text(trailing)
                .font(Theme.mono(11))
                .foregroundColor(done ? Theme.mint : Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.text.opacity(0.04)))
    }

    @ViewBuilder
    private var accessibilityStep: some View {
        if model.accessibilityGranted {
            stepRow(done: true, title: "accessibility", trailing: "granted")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("○").font(Theme.mono(14)).foregroundColor(Theme.accentLighter)
                    Text("accessibility").font(Theme.mono(12.5, .semibold))
                    Spacer()
                    Text("waiting…")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textSecondary)
                }
                Text("Turn on ClipSlots under Privacy & Security → Accessibility. This screen updates on its own.")
                    .font(Theme.mono(11.5))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 26)
                ActionButton(title: "Open System Settings", symbol: "arrow.up.right.square", primary: true) {
                    Permissions.requestAccessibility()
                }
                .padding(.leading, 26)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accentLight.opacity(0.4), lineWidth: 1))
        }
    }

    private var loginRow: some View {
        HStack(spacing: 12) {
            Text(model.launchAtLogin ? "●" : "○")
                .font(Theme.mono(14))
                .foregroundColor(model.launchAtLogin ? Theme.mint : Theme.textTertiary)
            Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                Text("start at login").font(Theme.mono(12.5))
            }
            .toggleStyle(.checkbox)
            .tint(Theme.mint)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.text.opacity(0.04)))
    }
}

enum Permissions {
    /// `prompt: true` registers the app with TCC (so it appears in the
    /// Accessibility list) and shows the system prompt the first time;
    /// then we open the pane directly so the toggle is one click away.
    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: SlotsModel
    private var timer: Timer?

    init(model: SlotsModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = Theme.backgroundNS
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let hosting = NSHostingController(rootView: OnboardingView(model: model) { [weak self] in self?.close() })
        hosting.sizingOptions = [.preferredContentSize]
        window.contentViewController = hosting
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present() {
        model.refreshAccessibility()
        model.refreshLoginItem()
        if window?.isVisible != true { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        startPolling()
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.model.refreshAccessibility()
        }
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }
}
