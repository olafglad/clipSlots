import Foundation

class SlotStorage {
    private let slotCount: Int
    private let fm = FileManager.default

    init(slotCount: Int) throws {
        self.slotCount = slotCount
        try Paths.ensureDirectoryExists(at: Paths.slotsDirectory)
        cleanupTempDirectories()
        try migrateIfNeeded()
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
        let slotDir = Paths.slotDirectory(slotNumber)
        if fm.fileExists(atPath: slotDir.path) {
            try fm.removeItem(at: slotDir)
        }
        try updateManifest()
    }

    func clearAll() throws {
        for i in 1...slotCount {
            let slotDir = Paths.slotDirectory(i)
            if fm.fileExists(atPath: slotDir.path) {
                try fm.removeItem(at: slotDir)
            }
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

        for i in 1...slotCount {
            guard let content = getSlot(i) else { continue }
            let allTypes = Array(Set(content.items.flatMap { $0.representations.map { $0.typeString } }))
            let totalBytes = content.items.flatMap { $0.representations }.reduce(0) { $0 + $1.data.count }

            entries.append(ManifestEntry(
                slot: i,
                description: content.contentDescription,
                types: allTypes,
                totalBytes: totalBytes,
                itemCount: content.items.count,
                updatedAt: formatter.string(from: Date())
            ))
        }

        let manifest = Manifest(entries: entries)
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
