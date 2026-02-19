import AppKit

class Clipboard {
    private let pasteboard = NSPasteboard.general

    var permissionStatus: PermissionStatus {
        // macOS 15.4+ will expose accessBehavior; for now assume allowed
        return .allowed
    }

    enum PermissionStatus {
        case allowed, promptEachTime, denied, unknown

        var description: String {
            switch self {
            case .allowed:        return "Allowed"
            case .promptEachTime: return "Prompt Each Time"
            case .denied:         return "Denied"
            case .unknown:        return "Unknown"
            }
        }

        var isUsable: Bool {
            self == .allowed || self == .promptEachTime
        }
    }

    func getCurrentContent() -> String? {
        guard permissionStatus.isUsable else { return nil }
        return pasteboard.string(forType: .string)
    }

    func setContent(_ content: String) -> Bool {
        guard permissionStatus.isUsable else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
    }

    func captureAll() -> SlotContent? {
        guard permissionStatus.isUsable else { return nil }
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        var snapshots: [PasteboardItemSnapshot] = []
        for item in items {
            var representations: [PasteboardRepresentation] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    representations.append(PasteboardRepresentation(typeString: type.rawValue, data: data))
                }
            }
            if !representations.isEmpty {
                snapshots.append(PasteboardItemSnapshot(representations: representations))
            }
        }

        guard !snapshots.isEmpty else { return nil }
        return SlotContent(items: snapshots)
    }

    func restoreAll(_ content: SlotContent) -> Bool {
        guard permissionStatus.isUsable else { return false }
        pasteboard.clearContents()

        for itemSnapshot in content.items {
            let item = NSPasteboardItem()
            for rep in itemSnapshot.representations {
                item.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.typeString))
            }
            pasteboard.writeObjects([item])
        }

        return true
    }

    var isEmpty: Bool {
        getCurrentContent()?.isEmpty ?? true
    }
}

enum ClipboardError: LocalizedError {
    case permissionDenied
    case emptyClipboard
    case failedToSet

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Pasteboard permission required. Run 'clipslots permissions' for instructions."
        case .emptyClipboard:
            return "Clipboard is empty. Copy something first."
        case .failedToSet:
            return "Failed to set clipboard content."
        }
    }
}
