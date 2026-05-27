import ArgumentParser
import Foundation
import AppKit

struct Open: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open a slot in the appropriate application",
        discussion: """
            Example:
              clipslots open 3   # text → $EDITOR, file → default app,
                                 # image → Preview, rich text → TextEdit/browser
            """
    )

    @Argument(help: "Slot number to open")
    var slot: Int

    mutating func run() throws {
        let config = try ConfigManager.load()
        let storage = try SlotStorage(slotCount: config.slots)

        guard (1...config.slots).contains(slot) else {
            throw ValidationError("Invalid slot number. Use 1-\(config.slots).")
        }

        guard let content = storage.getSlot(slot), !content.isEmpty else {
            throw ValidationError("Slot \(slot) is empty")
        }

        let action = try resolveAction(for: content)
        try action.execute(slot: slot)
    }

    // MARK: - Action resolution

    private enum OpenAction {
        case revealFile(URL)
        case openFile(URL)
        case revealFirstOfMany(URL)
        case writeAndOpen(data: Data, ext: String)
        case editText(String)

        func execute(slot: Int) throws {
            switch self {
            case .openFile(let url):
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("Slot \(slot): file no longer exists at \(url.path)")
                }
                NSWorkspace.shared.open(url)
                print("Opened \(url.path)")

            case .revealFile(let url):
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("Slot \(slot): file no longer exists at \(url.path)")
                }
                NSWorkspace.shared.activateFileViewerSelecting([url])
                print("Revealed \(url.path) in Finder")

            case .revealFirstOfMany(let url):
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("Slot \(slot): file no longer exists at \(url.path)")
                }
                NSWorkspace.shared.activateFileViewerSelecting([url])
                print("Revealed first file in Finder: \(url.path)")

            case .writeAndOpen(let data, let ext):
                let tempDir = URL(fileURLWithPath: "/tmp/clipslots-open", isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let path = tempDir.appendingPathComponent("slot-\(slot).\(ext)")
                try data.write(to: path, options: .atomic)
                NSWorkspace.shared.open(path)
                print("Opened slot \(slot) (\(ext)) at \(path.path)")

            case .editText(let text):
                guard let editor = ProcessInfo.processInfo.environment["EDITOR"], !editor.isEmpty else {
                    throw ValidationError("No $EDITOR set. Run 'export EDITOR=vim' (or similar) and try again.")
                }
                let tempDir = URL(fileURLWithPath: "/tmp/clipslots-open", isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let path = tempDir.appendingPathComponent("slot-\(slot).txt")
                try Data(text.utf8).write(to: path, options: .atomic)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", "\(editor) \"\(path.path)\""]
                try process.run()
                process.waitUntilExit()
            }
        }
    }

    private func resolveAction(for content: SlotContent) throws -> OpenAction {
        let allTypes = content.items.flatMap { $0.representations.map { $0.typeString } }

        // 1. File URLs
        if allTypes.contains("public.file-url") {
            let fileURLs = content.items.compactMap { item -> URL? in
                guard let rep = item.representations.first(where: { $0.typeString == "public.file-url" }),
                      let urlString = String(data: rep.data, encoding: .utf8),
                      let url = URL(string: urlString) else { return nil }
                return url
            }
            guard let first = fileURLs.first else {
                throw ValidationError("Slot \(slot): file-url representation could not be decoded")
            }
            if fileURLs.count > 1 {
                return .revealFirstOfMany(first)
            }
            return .openFile(first)
        }

        // 2. Images (prefer PNG, fall back to TIFF)
        if let pngData = content.items.first?.representations.first(where: { $0.typeString == "public.png" })?.data {
            return .writeAndOpen(data: pngData, ext: "png")
        }
        if let tiffData = content.items.first?.representations.first(where: { $0.typeString == "public.tiff" })?.data {
            return .writeAndOpen(data: tiffData, ext: "tiff")
        }

        // 3. Rich text — prefer RTF, then HTML (preserves formatting)
        if let rtfData = content.items.first?.representations.first(where: { $0.typeString == "public.rtf" })?.data {
            return .writeAndOpen(data: rtfData, ext: "rtf")
        }
        if let htmlData = content.items.first?.representations.first(where: { $0.typeString == "public.html" })?.data {
            return .writeAndOpen(data: htmlData, ext: "html")
        }

        // 4. Plain text → $EDITOR
        if let text = content.textPreview {
            return .editText(text)
        }

        // 5. Binary / unknown
        throw ValidationError("Slot \(slot) has no openable representation")
    }
}
