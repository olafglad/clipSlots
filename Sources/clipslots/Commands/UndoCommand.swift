import ArgumentParser
import Foundation

struct Undo: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Restore a slot to its previous content",
        discussion: """
            Example:
              clipslots undo 3   # swap slot 3 with its prior content;
                                 # running `undo 3` again round-trips back
            """
    )

    @Argument(help: "Slot number to undo")
    var slot: Int

    mutating func run() throws {
        let config = try ConfigManager.load()

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        let storage = try SlotStorage(slotCount: config.slots)
        do {
            try storage.undo(slot)
            print("Undid slot \(slot).")
        } catch SlotStorageError.slotLocked(let n) {
            FileHandle.standardError.write(Data("Slot \(n) is locked. Run `clipslots unlock \(n)` first.\n".utf8))
            throw ExitCode(1)
        } catch SlotStorageError.noUndoAvailable(let n) {
            FileHandle.standardError.write(Data("No previous content for slot \(n).\n".utf8))
            throw ExitCode(1)
        }
    }
}
