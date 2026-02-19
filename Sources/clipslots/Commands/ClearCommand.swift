import ArgumentParser
import Foundation

struct Clear: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clear one or all slots"
    )

    @Argument(help: "Slot number to clear (omit to clear all)")
    var slot: Int?

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        if let slotNumber = slot {
            guard (1...config.slots).contains(slotNumber) else {
                throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
            }
            try storage.clearSlot(slotNumber)
            print("Cleared slot \(slotNumber)")
        } else {
            print("Clear all slots? [y/N]: ", terminator: "")
            fflush(stdout)

            guard let response = readLine()?.lowercased(),
                  response == "y" || response == "yes" else {
                print("Cancelled")
                return
            }

            try storage.clearAll()
            print("Cleared all slots")
        }
    }
}
