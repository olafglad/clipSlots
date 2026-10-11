#if DEBUG
import AppKit
import SwiftUI

/// Renders popover states to PNG via ImageRenderer. AppKit-backed controls
/// (text fields, menus) render as placeholders; the layout is what matters.
enum Snapshot {
    @MainActor
    static func run(outputDirectory: String) {
        Theme.registerFonts()
        guard let engine = try? AppEngine() else {
            print("snapshot: could not load config/storage")
            return
        }
        let model = SlotsModel(engine: engine, version: AppDelegate.version)
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let first = model.slots.first(where: { !$0.isEmpty }) { model.select(first.number) }
        render(PopoverView(model: model), to: dir.appendingPathComponent("popover.png"))

        if let empty = model.slots.first(where: { $0.isEmpty }) {
            model.select(empty.number)
            render(PopoverView(model: model), to: dir.appendingPathComponent("popover-empty-selected.png"))
        }

        let filled = model.slots.filter { !$0.isEmpty }
        if let unlocked = filled.first(where: { !$0.locked }) {
            model.select(unlocked.number)
            render(PopoverView(model: model), to: dir.appendingPathComponent("popover-unlocked-selected.png"))
        }
        if filled.count >= 2 {
            model.select(filled[0].number)
            model.dragSource = filled[0].number
            model.dropTarget = filled[1].number
            render(PopoverView(model: model), to: dir.appendingPathComponent("popover-drag.png"))
            model.dragSource = nil
            model.dropTarget = nil
        }

        let peekTarget = model.slots.first(where: { $0.kind == .image }) ?? filled.first
        if let peek = peekTarget {
            model.peekSlot = peek.number
            render(PopoverView(model: model), to: dir.appendingPathComponent("peek.png"))
            model.peekSlot = nil
        }

        render(OnboardingView(model: model), to: dir.appendingPathComponent("onboarding.png"))
        print("snapshot: wrote PNGs to \(dir.path)")
    }

    @MainActor
    private static func render<V: View>(_ view: V, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            print("snapshot: failed to render \(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
    }
}
#endif
