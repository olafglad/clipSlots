import AppKit
import ApplicationServices
import SwiftUI

/// Setup window. Only appears while something is missing (today: the
/// Accessibility grant); it polls `AXIsProcessTrusted()` and closes itself
/// the moment the grant lands, so there is no "all set" screen to dismiss.
struct OnboardingView: View {
    @ObservedObject var model: SlotsModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let mascot = Mascot.image {
                    Image(nsImage: mascot)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityLabel("ClipSlots octopus mascot")
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("○").foregroundColor(Theme.danger)
                        Text("not all set yet").font(Theme.mono(15, .bold))
                    }
                    Text("Hotkeys can't save or paste until Accessibility is on.")
                        .font(Theme.mono(12))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 30)
            .padding(.bottom, 12)

            SectionHeader(title: "Setup", trailing: "1 of 2")
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 6)

            VStack(spacing: 8) {
                stepRow(title: "hotkeys engine running", trailing: "done")
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
                Link("docs", destination: URL(string: "https://clipslots.dev/docs/")!)
                    .foregroundColor(Theme.accentLight)
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

    private func stepRow(title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Text("●").font(Theme.mono(14)).foregroundColor(Theme.mint)
            Text(title).font(Theme.mono(12.5))
            Spacer()
            Text(trailing).font(Theme.mono(11)).foregroundColor(Theme.mint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.text.opacity(0.04)))
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("○").font(Theme.mono(14)).foregroundColor(Theme.accentLighter)
                Text("accessibility").font(Theme.mono(12.5, .semibold))
                Spacer()
                Text("waiting…")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.textSecondary)
            }
            Text("Turn on ClipSlots under Privacy & Security → Accessibility (Device Control and Data Access on newer macOS). This window closes on its own once it's on.")
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

    private var loginRow: some View {
        HStack(spacing: 12) {
            Text(model.launchAtLogin ? "●" : "○")
                .font(Theme.mono(14))
                .foregroundColor(model.launchAtLogin ? Theme.mint : Theme.textTertiary)
            Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                Text("start at login").font(Theme.mono(12.5))
            }
            .toggleStyle(.checkbox)
            Spacer()
            Text("optional")
                .font(Theme.mono(11))
                .foregroundColor(Theme.textTertiary)
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
    private let onGranted: () -> Void
    private var timer: Timer?

    init(model: SlotsModel, onGranted: @escaping () -> Void) {
        self.model = model
        self.onGranted = onGranted
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
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
        let hosting = NSHostingController(rootView: OnboardingView(model: model))
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
            guard let self = self else { return }
            self.model.refreshAccessibility()
            if self.model.accessibilityGranted {
                self.close()
                self.onGranted()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }
}
