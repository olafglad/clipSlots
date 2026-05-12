import ArgumentParser
import Foundation

struct Label: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set or clear a human-readable label for a slot"
    )

    @Argument(help: "Slot number to label")
    var slot: Int

    @Argument(help: "Label text (omit when using --clear)")
    var name: String?

    @Flag(name: .long, help: "Remove the label from this slot")
    var clear: Bool = false

    mutating func run() throws {
        let config = try ConfigManager.load()

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        if clear {
            if name != nil {
                throw ValidationError("Pass either a label or --clear, not both.")
            }
        } else {
            guard let name = name, !name.isEmpty else {
                throw ValidationError("Provide a label, or use --clear to remove the existing one.")
            }
            if name.count > 64 {
                throw ValidationError("Label is too long (max 64 characters).")
            }
        }

        let storage = try SlotStorage(slotCount: config.slots)
        try storage.setLabel(slot, label: clear ? nil : name)

        if clear {
            print("Cleared label on slot \(slot).")
        } else {
            print("Labeled slot \(slot): \(name ?? "")")
        }
    }
}
