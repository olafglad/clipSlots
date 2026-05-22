import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all slots with content preview"
    )

    @Option(name: .long, help: "Filter slots whose label or preview contains the pattern (case-insensitive).")
    var grep: String?

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        var rows = collectRows(storage: storage, slotCount: config.slots)
        if let pattern = grep, !pattern.isEmpty {
            let needle = pattern.lowercased()
            rows = rows.filter { row in
                if let label = row.label, label.lowercased().contains(needle) { return true }
                if let description = row.description, description.lowercased().contains(needle) { return true }
                return false
            }
        }

        let useColor = isatty(fileno(stdout)) != 0
        let maxLabelWidth = rows.compactMap { $0.label?.count }.max() ?? 0
        let showLabelColumn = maxLabelWidth > 0
        let anyLocked = rows.contains { $0.locked }

        for row in rows {
            print(format(row: row, labelWidth: maxLabelWidth, showLabelColumn: showLabelColumn, useColor: useColor, reserveLockColumn: anyLocked))
        }
    }

    private struct Row {
        let slot: Int
        let label: String?
        let description: String?
        let locked: Bool
    }

    private func collectRows(storage: SlotStorage, slotCount: Int) -> [Row] {
        var rows: [Row] = []
        let locks = storage.lockedSlots()
        // Try manifest first for speed, fall back to loading slots
        if let manifest = storage.getManifest() {
            let slotEntries = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.slot, $0) })
            for i in 1...slotCount {
                if let entry = slotEntries[i] {
                    rows.append(Row(slot: i, label: entry.label, description: entry.description, locked: entry.locked ?? false))
                } else {
                    rows.append(Row(slot: i, label: storage.getLabel(i), description: nil, locked: locks.contains(i)))
                }
            }
        } else {
            for i in 1...slotCount {
                let label = storage.getLabel(i)
                let description = storage.getSlot(i)?.contentDescription
                rows.append(Row(slot: i, label: label, description: description, locked: locks.contains(i)))
            }
        }
        return rows
    }

    private func format(row: Row, labelWidth: Int, showLabelColumn: Bool, useColor: Bool, reserveLockColumn: Bool) -> String {
        let lockGlyph = useColor ? "🔒" : "[L]"
        // Pad spaces wide enough to keep alignment when a glyph is absent.
        let lockSpacer = useColor ? "  " : "   "
        let lockColumn: String
        if reserveLockColumn {
            lockColumn = " " + (row.locked ? lockGlyph : lockSpacer)
        } else {
            lockColumn = ""
        }
        let slotColumn = "Slot \(row.slot)\(lockColumn)"
        let description = row.description ?? "(empty)"

        guard showLabelColumn else {
            return "\(slotColumn): \(description)"
        }

        let labelText = row.label ?? ""
        let paddedLabel = labelText.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        let coloredLabel = (useColor && !labelText.isEmpty)
            ? "\u{001B}[36m\(paddedLabel)\u{001B}[0m"
            : paddedLabel

        return "\(slotColumn)  \(coloredLabel)  \(description)"
    }
}

private var stdout: UnsafeMutablePointer<FILE> { Darwin.stdout }
