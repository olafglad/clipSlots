import Foundation
import AppKit

struct PasteboardRepresentation {
    let typeString: String
    let data: Data
}

struct PasteboardItemSnapshot {
    let representations: [PasteboardRepresentation]
}

struct SlotContent {
    let items: [PasteboardItemSnapshot]

    var isEmpty: Bool {
        items.isEmpty || items.allSatisfy { $0.representations.isEmpty }
    }

    var textPreview: String? {
        for item in items {
            for rep in item.representations {
                if rep.typeString == NSPasteboard.PasteboardType.string.rawValue,
                   let text = String(data: rep.data, encoding: .utf8), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    var contentDescription: String {
        let allTypes = items.flatMap { $0.representations.map { $0.typeString } }

        if allTypes.contains("public.file-url") {
            let fileCount = items.filter { item in
                item.representations.contains { $0.typeString == "public.file-url" }
            }.count
            if fileCount > 1 {
                return "[Files: \(fileCount) items]"
            }
            if let item = items.first,
               let rep = item.representations.first(where: { $0.typeString == "public.file-url" }),
               let urlString = String(data: rep.data, encoding: .utf8),
               let url = URL(string: urlString) {
                return "[File: \(url.lastPathComponent)]"
            }
            return "[File]"
        }

        if allTypes.contains("public.tiff") || allTypes.contains("public.png") {
            var label = "[Image"
            if let tiffData = items.first?.representations.first(where: { $0.typeString == "public.tiff" })?.data,
               let image = NSImage(data: tiffData) {
                let size = image.size
                label += " \(Int(size.width))x\(Int(size.height))"
            }
            label += "]"
            return label
        }

        if allTypes.contains("public.rtf") || allTypes.contains("public.html") {
            if let text = textPreview {
                let charCount = text.count
                let preview = previewString(text, maxLength: 40)
                return "[Rich Text] \(charCount) chars: \(preview)"
            }
            return "[Rich Text]"
        }

        if let text = textPreview {
            return previewString(text, maxLength: 50)
        }

        let totalBytes = items.flatMap { $0.representations }.reduce(0) { $0 + $1.data.count }
        let typeCount = Set(allTypes).count
        return "[Binary: \(typeCount) types, \(formatBytes(totalBytes))]"
    }

    private func previewString(_ text: String, maxLength: Int) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength - 3)) + "..."
        }
        return cleaned
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

struct ManifestEntry: Codable {
    let slot: Int
    let description: String
    let types: [String]
    let totalBytes: Int
    let itemCount: Int
    let updatedAt: String
}

struct Manifest: Codable {
    var entries: [ManifestEntry] = []
}
