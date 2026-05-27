import Foundation

enum SlotStorageError: Error, LocalizedError {
    case slotLocked(Int)

    var errorDescription: String? {
        switch self {
        case .slotLocked(let n):
            return "Slot \(n) is locked. Run `clipslots unlock \(n)` first."
        }
    }
}

class SlotStorage {
    private let slotCount: Int
    private let fm = FileManager.default

    init(slotCount: Int) throws {
        self.slotCount = slotCount
        try Paths.ensureDirectoryExists(at: Paths.slotsDirectory)
        cleanupTempDirectories()
        try migrateIfNeeded()
    }

    // MARK: - Labels

    /// Returns the label for a slot, or nil if none set.
    func getLabel(_ slotNumber: Int) -> String? {
        loadLabels()[String(slotNumber)]
    }

    /// Sets (or clears, when label is nil/empty) the label for a slot.
    func setLabel(_ slotNumber: Int, label: String?) throws {
        var labels = loadLabels()
        if let label = label, !label.isEmpty {
            labels[String(slotNumber)] = label
        } else {
            labels.removeValue(forKey: String(slotNumber))
        }
        try writeLabels(labels)
        try updateManifest()
    }

    private func loadLabels() -> [String: String] {
        guard let data = try? Data(contentsOf: Paths.labelsFile),
              let labels = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return labels
    }

    private func writeLabels(_ labels: [String: String]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(labels)
        try data.write(to: Paths.labelsFile, options: .atomic)
    }

    private func removeLabel(_ slotNumber: Int, persisting labels: inout [String: String]) {
        labels.removeValue(forKey: String(slotNumber))
    }

    // MARK: - Locks

    /// Returns true when the slot is currently locked.
    func isLocked(_ slotNumber: Int) -> Bool {
        loadLocks().contains(slotNumber)
    }

    /// Returns the set of currently locked slot numbers.
    func lockedSlots() -> Set<Int> {
        loadLocks()
    }

    /// Locks or unlocks a slot.
    func setLocked(_ slotNumber: Int, locked: Bool) throws {
        var locks = loadLocks()
        if locked {
            locks.insert(slotNumber)
        } else {
            locks.remove(slotNumber)
        }
        try writeLocks(locks)
        try updateManifest()
    }

    private func loadLocks() -> Set<Int> {
        guard let data = try? Data(contentsOf: Paths.locksFile),
              let array = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(array)
    }

    private func writeLocks(_ locks: Set<Int>) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(locks.sorted())
        try data.write(to: Paths.locksFile, options: .atomic)
    }

    // MARK: - Expiry state

    /// The timestamp at which the expiry feature was first enabled in the
    /// current session of being enabled. Nil when the feature is disabled
    /// (file absent). The age basis for `clearExpired` uses
    /// `max(slot_mtime, enabledAt)` so pre-existing stale slots get a
    /// fresh grace period equal to the TTL itself on first enable.
    func expiryEnabledAt() -> Date? {
        guard let data = try? Data(contentsOf: Paths.expiryStateFile),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let iso = dict["enabledAt"],
              let date = ISO8601DateFormatter().date(from: iso)
        else { return nil }
        return date
    }

    /// Marks the expiry feature as enabled starting at `at` (defaulting to
    /// now). Idempotent: if already marked, the timestamp is preserved.
    /// Returns the persisted timestamp.
    @discardableResult
    func markExpiryEnabled(at: Date = Date()) throws -> Date {
        if let existing = expiryEnabledAt() { return existing }
        let iso = ISO8601DateFormatter().string(from: at)
        let data = try JSONEncoder().encode(["enabledAt": iso])
        try data.write(to: Paths.expiryStateFile, options: .atomic)
        return at
    }

    /// Clears the persisted expiry-enabled marker. Called when the user
    /// disables the feature so the next enable earns a fresh grace period.
    func clearExpiryEnabled() throws {
        if fm.fileExists(atPath: Paths.expiryStateFile.path) {
            try fm.removeItem(at: Paths.expiryStateFile)
        }
    }

    // MARK: - Public API

    func getSlot(_ slotNumber: Int) -> SlotContent? {
        let slotDir = Paths.slotDirectory(slotNumber)
        guard fm.fileExists(atPath: slotDir.path) else { return nil }

        var items: [PasteboardItemSnapshot] = []
        guard let itemDirs = try? fm.contentsOfDirectory(at: slotDir, includingPropertiesForKeys: nil)
            .filter({ $0.lastPathComponent.hasPrefix("item_") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return nil
        }

        for itemDir in itemDirs {
            var representations: [PasteboardRepresentation] = []
            guard let files = try? fm.contentsOfDirectory(at: itemDir, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "bin" }) else {
                continue
            }
            for file in files {
                let typeString = decodeTypeName(file.deletingPathExtension().lastPathComponent)
                if let data = try? Data(contentsOf: file) {
                    representations.append(PasteboardRepresentation(typeString: typeString, data: data))
                }
            }
            if !representations.isEmpty {
                items.append(PasteboardItemSnapshot(representations: representations))
            }
        }

        guard !items.isEmpty else { return nil }
        return SlotContent(items: items)
    }

    func setSlot(_ slotNumber: Int, content: SlotContent) throws {
        if isLocked(slotNumber) {
            throw SlotStorageError.slotLocked(slotNumber)
        }
        let slotDir = Paths.slotDirectory(slotNumber)
        let tempDir = Paths.slotsDirectory.appendingPathComponent(".tmp_\(slotNumber)_\(ProcessInfo.processInfo.processIdentifier)")

        // Write to temp directory first
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        do {
            for (itemIndex, item) in content.items.enumerated() {
                let itemDir = tempDir.appendingPathComponent("item_\(itemIndex)")
                try fm.createDirectory(at: itemDir, withIntermediateDirectories: true)

                for rep in item.representations {
                    let fileName = encodeTypeName(rep.typeString) + ".bin"
                    let filePath = itemDir.appendingPathComponent(fileName)
                    try rep.data.write(to: filePath)
                }
            }

            // Atomic swap: remove old, rename temp into place
            if fm.fileExists(atPath: slotDir.path) {
                try fm.removeItem(at: slotDir)
            }
            try fm.moveItem(at: tempDir, to: slotDir)

            try updateManifest()
        } catch {
            // Cleanup temp on failure
            try? fm.removeItem(at: tempDir)
            throw error
        }
    }

    func clearSlot(_ slotNumber: Int) throws {
        if isLocked(slotNumber) {
            throw SlotStorageError.slotLocked(slotNumber)
        }
        let slotDir = Paths.slotDirectory(slotNumber)
        if fm.fileExists(atPath: slotDir.path) {
            try fm.removeItem(at: slotDir)
        }
        var labels = loadLabels()
        removeLabel(slotNumber, persisting: &labels)
        try writeLabels(labels)
        try updateManifest()
    }

    /// Clears every slot, optionally skipping locked slots.
    /// When `respectLocks` is false, locks themselves are also wiped.
    func clearAll(respectLocks: Bool) throws {
        let locks = loadLocks()
        var labels = loadLabels()
        for i in 1...slotCount {
            if respectLocks && locks.contains(i) { continue }
            let slotDir = Paths.slotDirectory(i)
            if fm.fileExists(atPath: slotDir.path) {
                try fm.removeItem(at: slotDir)
            }
            labels.removeValue(forKey: String(i))
        }
        try writeLabels(labels)
        if respectLocks {
            // Keep existing locks intact.
        } else {
            try writeLocks([])
        }
        try updateManifest()
    }

    func isSlotEmpty(_ slotNumber: Int) -> Bool {
        let slotDir = Paths.slotDirectory(slotNumber)
        return !fm.fileExists(atPath: slotDir.path)
    }

    func getAllSlots() -> [Int: SlotContent?] {
        var result: [Int: SlotContent?] = [:]
        for i in 1...slotCount {
            result[i] = getSlot(i)
        }
        return result
    }

    /// Forces a rebuild of the manifest cache from on-disk slot state.
    func refreshManifest() throws {
        try updateManifest()
    }

    /// Clears every non-locked slot whose effective age exceeds
    /// `olderThanSeconds`. The age basis for each slot is
    /// `now - max(slot_mtime, enabledFloor)`, so pre-existing stale slots
    /// get a grace period equal to the TTL itself before the first sweep
    /// can touch them. `enabledFloor` should be the timestamp at which
    /// the expiry feature was first enabled in the current session
    /// (see `expiryEnabledAt`). When `enabledFloor` is nil the floor is
    /// ignored. Returns each cleared slot with its true mtime — the
    /// caller is expected to log it. A single manifest rebuild covers
    /// the whole sweep.
    func clearExpired(olderThanSeconds: TimeInterval, enabledFloor: Date?, now: Date = Date()) throws -> [(slot: Int, mtime: Date)] {
        let locks = loadLocks()
        var labels = loadLabels()
        var cleared: [(slot: Int, mtime: Date)] = []

        for i in 1...slotCount {
            if locks.contains(i) { continue }
            let slotDir = Paths.slotDirectory(i)
            guard fm.fileExists(atPath: slotDir.path),
                  let mtime = try? fm.attributesOfItem(atPath: slotDir.path)[.modificationDate] as? Date
            else { continue }

            // Grace-period floor: a slot's effective "age starts here"
            // is the later of its own mtime and the moment the feature
            // was enabled. Without this, enabling expiry would wipe any
            // already-stale slot the user might have wanted to keep.
            let ageBasis: Date
            if let floor = enabledFloor, floor > mtime {
                ageBasis = floor
            } else {
                ageBasis = mtime
            }

            if now.timeIntervalSince(ageBasis) >= olderThanSeconds {
                try fm.removeItem(at: slotDir)
                labels.removeValue(forKey: String(i))
                cleared.append((slot: i, mtime: mtime))
            }
        }

        guard !cleared.isEmpty else { return [] }
        try writeLabels(labels)
        try updateManifest()
        return cleared
    }

    func getManifest() -> Manifest? {
        guard let data = try? Data(contentsOf: Paths.manifestFile) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    func getMaxSlot() -> Int {
        slotCount
    }

    // MARK: - Manifest

    private func updateManifest() throws {
        var entries: [ManifestEntry] = []
        let formatter = ISO8601DateFormatter()
        let labels = loadLabels()
        let locks = loadLocks()

        for i in 1...slotCount {
            guard let content = getSlot(i) else { continue }
            let allTypes = Array(Set(content.items.flatMap { $0.representations.map { $0.typeString } }))
            let totalBytes = content.items.flatMap { $0.representations }.reduce(0) { $0 + $1.data.count }

            // Source of truth for "when was this slot last written" is the
            // per-slot directory's mtime. setSlot atomically renames a temp
            // dir into place, which updates mtime correctly. Stamping
            // Date() here would re-stamp every slot on every manifest
            // rebuild, making all ages look identical.
            let slotDir = Paths.slotDirectory(i)
            let mtime = (try? fm.attributesOfItem(atPath: slotDir.path)[.modificationDate] as? Date) ?? Date()

            entries.append(ManifestEntry(
                slot: i,
                description: content.contentDescription,
                types: allTypes,
                totalBytes: totalBytes,
                itemCount: content.items.count,
                updatedAt: formatter.string(from: mtime),
                label: labels[String(i)],
                locked: locks.contains(i) ? true : nil
            ))
        }

        let manifest = Manifest(version: Manifest.currentVersion, entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: Paths.manifestFile, options: .atomic)
    }

    // MARK: - Filename Encoding

    private func encodeTypeName(_ typeString: String) -> String {
        typeString.replacingOccurrences(of: "/", with: "_SLASH_")
    }

    private func decodeTypeName(_ fileName: String) -> String {
        fileName.replacingOccurrences(of: "_SLASH_", with: "/")
    }

    // MARK: - Migration

    private func migrateIfNeeded() throws {
        let oldFile = Paths.slotsFile
        guard fm.fileExists(atPath: oldFile.path) else { return }

        // Inline old SlotData for deserialization
        struct OldSlotData: Codable {
            var slots: [String: String?] = [:]
            var updatedAt: Date = Date()

            enum CodingKeys: String, CodingKey {
                case slots
                case updatedAt = "updated_at"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                slots = try container.decode([String: String?].self, forKey: .slots)
                if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
                    updatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
                } else {
                    updatedAt = Date()
                }
            }
        }

        do {
            let jsonData = try Data(contentsOf: oldFile)
            let oldData = try JSONDecoder().decode(OldSlotData.self, from: jsonData)

            for (key, value) in oldData.slots {
                guard let slotNum = Int(key), let text = value, !text.isEmpty else { continue }
                let textData = Data(text.utf8)
                let rep = PasteboardRepresentation(
                    typeString: "public.utf8-plain-text",
                    data: textData
                )
                let item = PasteboardItemSnapshot(representations: [rep])
                let content = SlotContent(items: [item])
                try setSlot(slotNum, content: content)
            }

            // Rename old file to .bak
            let backupFile = oldFile.deletingPathExtension().appendingPathExtension("json.bak")
            if fm.fileExists(atPath: backupFile.path) {
                try fm.removeItem(at: backupFile)
            }
            try fm.moveItem(at: oldFile, to: backupFile)

            print("Migrated slots from old format. Backup saved to \(backupFile.path)")
        } catch {
            print("Warning: Could not migrate old slots file: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    private func cleanupTempDirectories() {
        guard let contents = try? fm.contentsOfDirectory(at: Paths.slotsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for item in contents where item.lastPathComponent.hasPrefix(".tmp_") {
            try? fm.removeItem(at: item)
        }
    }
}
