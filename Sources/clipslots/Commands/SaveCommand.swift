import ArgumentParser
import Foundation

struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save current clipboard content to a slot"
    )

    @Argument(help: "Slot number to save to")
    var slot: Int

    mutating func run() throws {
        let config = try ConfigManager.load()

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        let clipboard = Clipboard()
        let storage = try SlotStorage(slotCount: config.slots)

        guard clipboard.permissionStatus.isUsable else {
            throw ClipboardError.permissionDenied
        }

        guard let content = clipboard.captureAll() else {
            throw ClipboardError.emptyClipboard
        }

        try storage.setSlot(slot, content: content)
        print("Saved to slot \(slot): \(content.contentDescription)")
    }
}
