import ArgumentParser
import Foundation

struct Copy: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Copy the contents of one slot into another"
    )

    @Argument(help: "Source slot")
    var src: Int

    @Argument(help: "Destination slot")
    var dst: Int

    mutating func run() throws {
        let config = try ConfigManager.load()
        let range = 1...config.slots

        guard range.contains(src) else {
            throw ValidationError("Invalid slot number \(src). Use 1-\(config.slots).")
        }
        guard range.contains(dst) else {
            throw ValidationError("Invalid slot number \(dst). Use 1-\(config.slots).")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        do {
            try storage.copy(from: src, to: dst)
            print("Copied slot \(src) to slot \(dst).")
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
