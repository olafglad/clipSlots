import ArgumentParser
import Foundation

struct Clear: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clear one or all slots"
    )

    @Argument(help: "Slot number to clear (omit to clear all)")
    var slot: Int?

    @Flag(name: .long, help: "Clear every slot, including locked ones. Non-interactive.")
    var force: Bool = false

    @Flag(name: .long, help: "Clear only unlocked slots, keep locked ones. Non-interactive.")
    var keepLocked: Bool = false

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        if let slotNumber = slot {
            guard (1...config.slots).contains(slotNumber) else {
                throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
            }
            if force {
                if storage.isLocked(slotNumber) {
                    try storage.setLocked(slotNumber, locked: false)
                }
                try storage.clearSlot(slotNumber)
                print("Cleared slot \(slotNumber)")
                return
            }
            do {
                try storage.clearSlot(slotNumber)
                print("Cleared slot \(slotNumber)")
            } catch SlotStorageError.slotLocked(let n) {
                FileHandle.standardError.write(Data("Slot \(n) is locked. Rerun with --force to clear it.\n".utf8))
                throw ExitCode(1)
            }
            return
        }

        if force && keepLocked {
            throw ValidationError("Pass either --force or --keep-locked, not both.")
        }

        let lockedSorted = storage.lockedSlots().sorted()

        if force {
            try storage.clearAll(respectLocks: false)
            print("Cleared all slots")
            return
        }

        if keepLocked {
            try storage.clearAll(respectLocks: true)
            if lockedSorted.isEmpty {
                print("Cleared all slots")
            } else {
                print("Cleared all unlocked slots (kept locked: \(lockedSorted.map(String.init).joined(separator: ", ")))")
            }
            return
        }

        // No locked slots: behave exactly like the old simple confirmation.
        if lockedSorted.isEmpty {
            print("Clear all slots? [y/N]: ", terminator: "")
            fflush(stdout)
            guard let response = readLine()?.lowercased(),
                  response == "y" || response == "yes" else {
                print("Cancelled")
                return
            }
            try storage.clearAll(respectLocks: false)
            print("Cleared all slots")
            return
        }

        // Locked slots present and no flags chosen.
        guard isatty(fileno(stdin)) != 0 else {
            let list = lockedSorted.map(String.init).joined(separator: ", ")
            FileHandle.standardError.write(Data("clear: locked slots present (\(list)); rerun with --force to clear all or --keep-locked to preserve them\n".utf8))
            throw ExitCode(1)
        }

        printLockedWarning(lockedSorted: lockedSorted, storage: storage)
        print("")
        print("Choose:")
        print("  [a] Clear all slots (including locked)")
        print("  [k] Clear only unlocked slots (keep locked)")
        print("  [q] Abort")
        print("> ", terminator: "")
        fflush(stdout)

        let choice = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        switch choice {
        case "a":
            try storage.clearAll(respectLocks: false)
            print("Cleared all slots")
        case "k":
            try storage.clearAll(respectLocks: true)
            print("Cleared all unlocked slots (kept locked: \(lockedSorted.map(String.init).joined(separator: ", ")))")
        default:
            print("Cancelled")
        }
    }

    private func printLockedWarning(lockedSorted: [Int], storage: SlotStorage) {
        print("The following slots are locked:")
        for n in lockedSorted {
            if let label = storage.getLabel(n) {
                print("  Slot \(n)  \(label)")
            } else {
                print("  Slot \(n)")
            }
        }
    }
}

private var stdin: UnsafeMutablePointer<FILE> { Darwin.stdin }
private var stdout: UnsafeMutablePointer<FILE> { Darwin.stdout }
