import ArgumentParser
import Foundation

struct Peek: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the text content of a slot to stdout",
        discussion: """
            Examples:
              clipslots peek 3
              TOKEN=$(clipslots peek 7)
              diff <(clipslots peek 1) <(clipslots peek 2)
            """
    )

    @Argument(help: "Slot number to peek")
    var slot: Int

    @Option(name: .long, help: "Truncate output to N characters (no truncation by default)")
    var truncate: Int?

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        guard let content = storage.getSlot(slot), !content.isEmpty else {
            // Empty slot: exit 0, no output. Matches `cat /dev/null`.
            return
        }

        guard let text = content.textPreview else {
            FileHandle.standardError.write(Data("slot \(slot): \(content.contentDescription)\n".utf8))
            throw ExitCode(2)
        }

        var output = text
        if let limit = truncate, limit >= 0, text.count > limit {
            output = String(text.prefix(limit))
        }

        FileHandle.standardOutput.write(Data(output.utf8))

        // Append trailing newline only when stdout is a TTY.
        if isatty(fileno(stdout)) != 0 {
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
}
