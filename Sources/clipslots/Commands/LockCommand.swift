import ArgumentParser
import Foundation

struct Lock: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Lock a slot so it cannot be overwritten or cleared",
        discussion: """
            Example:
              clipslots lock 3   # save/clear/undo refuse until 'unlock 3'
            """
    )

    @Argument(help: "Slot number to lock")
    var slot: Int

    mutating func run() throws {
        let config = try ConfigManager.load()

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        if storage.isLocked(slot) {
            print("Slot \(slot) is already locked.")
            return
        }
        try storage.setLocked(slot, locked: true)
        print("Locked slot \(slot).")
    }
}
