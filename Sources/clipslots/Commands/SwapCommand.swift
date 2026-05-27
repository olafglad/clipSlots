import ArgumentParser
import Foundation

struct Swap: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Swap the contents of two slots"
    )

    @Argument(help: "First slot")
    var a: Int

    @Argument(help: "Second slot")
    var b: Int

    mutating func run() throws {
        let config = try ConfigManager.load()
        let range = 1...config.slots

        guard range.contains(a) else {
            throw ValidationError("Invalid slot number \(a). Use 1-\(config.slots).")
        }
        guard range.contains(b) else {
            throw ValidationError("Invalid slot number \(b). Use 1-\(config.slots).")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        do {
            try storage.swap(a, b)
            print("Swapped slots \(a) and \(b).")
        } catch SlotStorageError.sameSlot {
            FileHandle.standardError.write(Data("Source and destination must differ.\n".utf8))
            throw ExitCode(1)
        } catch SlotStorageError.slotLocked(let n) {
            FileHandle.standardError.write(Data("Slot \(n) is locked. Run `clipslots unlock \(n)` first.\n".utf8))
            throw ExitCode(1)
        } catch SlotStorageError.slotEmpty(let n) {
            FileHandle.standardError.write(Data("Slot \(n) is empty.\n".utf8))
            throw ExitCode(1)
        }
    }
}
