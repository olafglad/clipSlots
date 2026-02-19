import Foundation

struct SlotData: Codable {
    var slots: [String: String?] = [:]
    var updatedAt: Date = Date()

    init(slotCount: Int) {
        for i in 1...slotCount {
            slots[String(i)] = nil
        }
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slots, forKey: .slots)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case slots
        case updatedAt = "updated_at"
    }

    func getSlot(_ slotNumber: Int) -> String? {
        slots[String(slotNumber)] ?? nil
    }

    mutating func setSlot(_ slotNumber: Int, content: String?) {
        slots[String(slotNumber)] = content
        updatedAt = Date()
    }

    mutating func clearSlot(_ slotNumber: Int) {
        slots[String(slotNumber)] = nil
        updatedAt = Date()
    }

    mutating func clearAll() {
        for key in slots.keys {
            slots[key] = nil
        }
        updatedAt = Date()
    }

    func isSlotEmpty(_ slotNumber: Int) -> Bool {
        let content = slots[String(slotNumber)] ?? nil
        return content == nil || content?.isEmpty == true
    }

    mutating func adjustSlotCount(to newCount: Int) {
        for num in slots.keys.compactMap({ Int($0) }) where num > newCount {
            slots.removeValue(forKey: String(num))
        }
        for i in 1...newCount {
            if slots[String(i)] == nil {
                slots[String(i)] = nil
            }
        }
        updatedAt = Date()
    }
}

class SlotStorage {
    private let fileURL = Paths.slotsFile
    private var data: SlotData

    init(slotCount: Int) throws {
        try Paths.ensureDirectoryExists(at: Paths.dataDirectory)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let jsonData = try Data(contentsOf: fileURL)
                var loadedData = try JSONDecoder().decode(SlotData.self, from: jsonData)
                loadedData.adjustSlotCount(to: slotCount)
                self.data = loadedData
                try save()
            } catch {
                print("Warning: Could not load slots file, creating new one: \(error.localizedDescription)")
                self.data = SlotData(slotCount: slotCount)
                try save()
            }
        } else {
            self.data = SlotData(slotCount: slotCount)
            try save()
        }
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: fileURL, options: .atomic)
    }

    func getSlot(_ slotNumber: Int) -> String? {
        data.getSlot(slotNumber)
    }

    func setSlot(_ slotNumber: Int, content: String?) throws {
        data.setSlot(slotNumber, content: content)
        try save()
    }

    func clearSlot(_ slotNumber: Int) throws {
        data.clearSlot(slotNumber)
        try save()
    }

    func clearAll() throws {
        data.clearAll()
        try save()
    }

    func isSlotEmpty(_ slotNumber: Int) -> Bool {
        data.isSlotEmpty(slotNumber)
    }

    func getAllSlots() -> [Int: String?] {
        var result: [Int: String?] = [:]
        for (key, value) in data.slots {
            if let slotNumber = Int(key) {
                result[slotNumber] = value
            }
        }
        return result
    }

    func getMaxSlot() -> Int {
        data.slots.keys.compactMap { Int($0) }.max() ?? 5
    }
}
