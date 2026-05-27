import ArgumentParser
import Foundation

struct Unlock: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Unlock a slot so it can be overwritten again",
        discussion: """
            Example:
              clipslots unlock 3
            """
    )

    @Argument(help: "Slot number to unlock")
    var slot: Int

    mutating func run() throws {
        let config = try ConfigManager.load()

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        if !storage.isLocked(slot) {
            print("Slot \(slot) is not locked.")
            return
        }
        try storage.setLocked(slot, locked: false)
        print("Unlocked slot \(slot).")
    }
}
