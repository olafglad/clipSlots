import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all slots with content preview"
    )

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        // Try manifest first for speed, fall back to loading slots
        if let manifest = storage.getManifest() {
            let slotEntries = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.slot, $0) })
            for i in 1...config.slots {
                if let entry = slotEntries[i] {
                    print("Slot \(i): \(entry.description)")
                } else {
                    print("Slot \(i): (empty)")
                }
            }
        } else {
            for i in 1...config.slots {
                if let content = storage.getSlot(i) {
                    print("Slot \(i): \(content.contentDescription)")
                } else {
                    print("Slot \(i): (empty)")
                }
            }
        }
    }
}
