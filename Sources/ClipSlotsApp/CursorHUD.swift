import AppKit
import SwiftUI

/// Small purple checkmark that sits on top of the mouse pointer to confirm
/// a copy, follows it while visible, then fades. Click-through and never
/// takes focus, so it can't get in the way of the ⌘V that usually follows.
/// (The real cursor can't be swapped: macOS only lets the frontmost app set
/// it, and ClipSlots deliberately never becomes frontmost.)
final class CursorHUD {
    static let shared = CursorHUD()

    private let size: CGFloat = 34
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }()
    private var fadeWork: DispatchWorkItem?
    private var followTimer: Timer?

    /// Centre of the badge relative to the pointer's hotspot (the arrow's
    /// tip): up and to the left, so it hugs the tip without covering the
    /// arrow. The 24pt circle's edge ends just short of the hotspot.
    private let offset = NSPoint(x: -11, y: 11)

    private func frameAtPointer() -> NSRect {
        let mouse = NSEvent.mouseLocation
        return NSRect(x: mouse.x + offset.x - size / 2, y: mouse.y + offset.y - size / 2, width: size, height: size)
    }

    func flashCheckmark() {
        panel.setFrame(frameAtPointer(), display: false)
        // A fresh view each time so the pop-in animation replays.
        panel.contentView = NSHostingView(rootView: CheckBadge())
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        followTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.panel.setFrameOrigin(self.frameAtPointer().origin)
        }
        RunLoop.main.add(timer, forMode: .common)
        followTimer = timer

        fadeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                if panel.alphaValue == 0 {
                    panel.orderOut(nil)
                    self?.followTimer?.invalidate()
                    self?.followTimer = nil
                }
            })
        }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }
}

private struct CheckBadge: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent)
                .overlay(Circle().strokeBorder(Theme.accentLighter.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 24, height: 24)
        .scaleEffect(shown ? 1 : 0.4)
        .opacity(shown ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { shown = true }
        }
        .accessibilityLabel("Copied")
    }
}
