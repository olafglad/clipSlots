import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show all slots with content preview"
    )

    @Option(name: .long, help: "Filter slots whose label or preview contains the pattern (case-insensitive).")
    var grep: String?

    @Flag(name: .shortAndLong, help: "Show per-slot metadata (size, types, age, label, lock state).")
    var verbose: Bool = false

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

        if verbose {
            let now = Date()
            for (index, row) in rows.enumerated() {
                if index > 0 { print("") }
                printVerbose(row: row, useColor: useColor, now: now)
            }
            return
        }

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
        let types: [String]?
        let totalBytes: Int?
        let updatedAt: String?
    }

    private func collectRows(storage: SlotStorage, slotCount: Int) -> [Row] {
        var rows: [Row] = []
        let locks = storage.lockedSlots()
        // Try manifest first for speed, fall back to loading slots
        if let manifest = storage.getManifest() {
            let slotEntries = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.slot, $0) })
            for i in 1...slotCount {
                if let entry = slotEntries[i] {
                    rows.append(Row(
                        slot: i,
                        label: entry.label,
                        description: entry.description,
                        locked: entry.locked ?? false,
                        types: entry.types,
                        totalBytes: entry.totalBytes,
                        updatedAt: entry.updatedAt
                    ))
                } else {
                    rows.append(Row(
                        slot: i,
                        label: storage.getLabel(i),
                        description: nil,
                        locked: locks.contains(i),
                        types: nil,
                        totalBytes: nil,
                        updatedAt: nil
                    ))
                }
            }
        } else {
            for i in 1...slotCount {
                let label = storage.getLabel(i)
                let description = storage.getSlot(i)?.contentDescription
                rows.append(Row(
                    slot: i,
                    label: label,
                    description: description,
                    locked: locks.contains(i),
                    types: nil,
                    totalBytes: nil,
                    updatedAt: nil
                ))
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

    private func printVerbose(row: Row, useColor: Bool, now: Date) {
        let lockGlyph = useColor ? "🔒" : "[L]"
        var header = "Slot \(row.slot)"
        if let label = row.label, !label.isEmpty {
            let coloredLabel = useColor ? "\u{001B}[36m\(label)\u{001B}[0m" : label
            header += "  \(coloredLabel)"
        }
        if row.locked {
            header += "  \(lockGlyph)"
        }
        print(header)

        print("  \(row.description ?? "(empty)")")

        // The remaining fields only exist when the manifest had an entry for this slot.
        if let bytes = row.totalBytes {
            print("  size:    \(formatBytes(bytes))")
        }
        if let types = row.types, !types.isEmpty {
            print("  types:   \(types.joined(separator: ", "))")
        }
        if let updatedAt = row.updatedAt, let date = ISO8601DateFormatter().date(from: updatedAt) {
            print("  age:     \(relativeAge(from: date, to: now))")
        }
        if row.totalBytes != nil {
            print("  locked:  \(row.locked ? "yes" : "no")")
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    private func relativeAge(from date: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 30 { return "\(days)d ago" }
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        let years = days / 365
        return "\(years)y ago"
    }
}

private var stdout: UnsafeMutablePointer<FILE> { Darwin.stdout }
