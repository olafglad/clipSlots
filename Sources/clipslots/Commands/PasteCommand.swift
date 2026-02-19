import ArgumentParser
import Foundation

struct Paste: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Load slot content to clipboard"
    )

    @Argument(help: "Slot number to paste from")
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

        guard let content = storage.getSlot(slot) else {
            throw ValidationError("Slot \(slot) is empty. Save something first with 'clipslots save \(slot)'.")
        }

        guard clipboard.restoreAll(content) else {
            throw ClipboardError.failedToSet
        }

        print("Slot \(slot) copied to clipboard: \(content.contentDescription)")
    }
}
