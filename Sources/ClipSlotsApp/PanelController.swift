import AppKit
import SwiftUI

/// Borderless floating panel that hosts the slot list. Replaces NSPopover,
/// which re-anchors to the screen corner whenever SwiftUI content changes
/// size. Non-activating, so the app the user was in stays frontmost: typing
/// goes to the panel, and once it closes ⌘V lands back in that app.
final class SlotsPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the panel: where it opens, keeping its top edge pinned as the
/// content grows or shrinks, header dragging, and remembering the spot.
final class PanelController: NSObject, NSWindowDelegate {
    let panel = SlotsPanel()
    /// Called when the panel hides by losing focus (click elsewhere).
    var onHide: () -> Void = {}

    private static let positionKey = "panelTopLeft"
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var lastHide = Date.distantPast

    private var fittingSize: () -> NSSize = { .zero }

    init<Content: View>(rootView: Content) {
        super.init()
        let hosting = SelfSizingHostingView(rootView: rootView)
        hosting.onIntrinsicSizeChange = { [weak self] in self?.fitToContent() }
        fittingSize = { [weak hosting] in
            hosting?.layoutSubtreeIfNeeded()
            return hosting?.fittingSize ?? .zero
        }
        panel.contentView = hosting
        panel.delegate = self
    }

    var isVisible: Bool { panel.isVisible }

    /// True right after the panel hid by losing focus. A click on the
    /// menubar icon first steals focus (hiding the panel) and then fires the
    /// icon's action; without this check the panel would pop straight back.
    var justHid: Bool { Date().timeIntervalSince(lastHide) < 0.3 }

    func show(below statusButton: NSStatusBarButton?) {
        let topLeft = savedTopLeft() ?? defaultTopLeft(below: statusButton)
        // Measure before showing: SwiftUI may not have laid out the new
        // state (filter cleared, peek closed) while the panel was hidden.
        place(topLeft: topLeft, size: measuredSize())
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onHide()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible else { return }
        lastHide = Date()
        hide()
    }

    // MARK: - Sizing

    /// Content changed size (row expanded, filter applied, peek opened):
    /// grow or shrink downward from a fixed top edge.
    func fitToContent() {
        let size = measuredSize()
        guard size != panel.frame.size else { return }
        place(topLeft: NSPoint(x: panel.frame.minX, y: panel.frame.maxY), size: size)
    }

    private func measuredSize() -> NSSize {
        let size = fittingSize()
        return size.width > 0 && size.height > 0 ? size : panel.frame.size
    }

    private func place(topLeft: NSPoint, size: CGSize) {
        var frame = NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        if let visible = screen(containing: topLeft)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    // MARK: - Position memory

    private func defaultTopLeft(below button: NSStatusBarButton?) -> NSPoint {
        if let button = button, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            return NSPoint(x: rect.midX - panel.frame.width / 2, y: rect.minY - 6)
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: visible.maxX - panel.frame.width - 12, y: visible.maxY - 6)
    }

    private func savedTopLeft() -> NSPoint? {
        guard let string = UserDefaults.standard.string(forKey: Self.positionKey) else { return nil }
        let point = NSPointFromString(string)
        // Ignore a spot on a display that is no longer connected.
        return screen(containing: point) == nil ? nil : point
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.positionKey)
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
    }

    // MARK: - Header drag

    func dragChanged() {
        let mouse = NSEvent.mouseLocation
        if dragStartMouse == nil {
            dragStartMouse = mouse
            dragStartOrigin = panel.frame.origin
        }
        guard let startMouse = dragStartMouse, let startOrigin = dragStartOrigin else { return }
        panel.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x,
                                     y: startOrigin.y + mouse.y - startMouse.y))
    }

    func dragEnded() {
        dragStartMouse = nil
        dragStartOrigin = nil
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        UserDefaults.standard.set(NSStringFromPoint(topLeft), forKey: Self.positionKey)
    }
}

// MARK: - SwiftUI glue

/// NSHostingView that tells us whenever SwiftUI's ideal size changes, so
/// the panel can track it. Deferred a runloop turn: resizing the window
/// from inside SwiftUI's own layout pass is ignored.
final class SelfSizingHostingView<Content: View>: NSHostingView<Content> {
    var onIntrinsicSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.onIntrinsicSizeChange?() }
    }
}

/// Root of the panel: the slot UI at its natural size, with rounded corners.
struct PanelRootView: View {
    @ObservedObject var model: SlotsModel

    var body: some View {
        PopoverView(model: model)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.text.opacity(0.12), lineWidth: 1)
            )
            .fixedSize()
    }
}
