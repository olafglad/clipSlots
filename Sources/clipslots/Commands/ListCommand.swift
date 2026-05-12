import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all slots with content preview"
    )

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        let rows = collectRows(storage: storage, slotCount: config.slots)
        let useColor = isatty(fileno(stdout)) != 0
        let maxLabelWidth = rows.compactMap { $0.label?.count }.max() ?? 0
        let showLabelColumn = maxLabelWidth > 0

        for row in rows {
            print(format(row: row, labelWidth: maxLabelWidth, showLabelColumn: showLabelColumn, useColor: useColor))
        }
    }

    private struct Row {
        let slot: Int
        let label: String?
        let description: String?
    }

    private func collectRows(storage: SlotStorage, slotCount: Int) -> [Row] {
        var rows: [Row] = []
        // Try manifest first for speed, fall back to loading slots
        if let manifest = storage.getManifest() {
            let slotEntries = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.slot, $0) })
            for i in 1...slotCount {
                if let entry = slotEntries[i] {
                    rows.append(Row(slot: i, label: entry.label, description: entry.description))
                } else {
                    rows.append(Row(slot: i, label: storage.getLabel(i), description: nil))
                }
            }
        } else {
            for i in 1...slotCount {
                let label = storage.getLabel(i)
                let description = storage.getSlot(i)?.contentDescription
                rows.append(Row(slot: i, label: label, description: description))
            }
        }
        return rows
    }

    private func format(row: Row, labelWidth: Int, showLabelColumn: Bool, useColor: Bool) -> String {
        let slotColumn = "Slot \(row.slot)"
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
