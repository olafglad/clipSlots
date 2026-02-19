import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all slots with content preview"
    )

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)
        let allSlots = storage.getAllSlots()

        for i in 1...config.slots {
            if let content = allSlots[i], let text = content, !text.isEmpty {
                let preview = text.count > 50 ? String(text.prefix(47)) + "..." : text
                print("Slot \(i): \(preview.replacingOccurrences(of: "\n", with: " "))")
            } else {
                print("Slot \(i): (empty)")
            }
        }
    }
}
