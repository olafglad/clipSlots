import AppKit
import ClipSlotsCore
import ServiceManagement

enum SlotKind {
    case text, link, image, rich, file, binary, empty

    var symbol: String {
        switch self {
        case .text:   return "text.alignleft"
        case .link:   return "link"
        case .image:  return "photo"
        case .rich:   return "paragraphsign"
        case .file:   return "doc"
        case .binary: return "shippingbox"
        case .empty:  return "square.dashed"
        }
    }
}

struct SlotItem: Identifiable {
    let number: Int
    let content: SlotContent?
    let kind: SlotKind
    let label: String?
    let locked: Bool
    let updatedAt: Date?
    /// One-line description for the list row (same wording as `clipslots list`).
    let summary: String
    let image: NSImage?
    let totalBytes: Int
    let canUndo: Bool

    var id: Int { number }
    var isEmpty: Bool { content == nil }

    var linkURL: URL? {
        guard kind == .link, let text = content?.textPreview else { return nil }
        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var fileURLs: [URL] {
        guard let content = content else { return [] }
        return content.items.compactMap { item in
            guard let rep = item.representations.first(where: { $0.typeString == "public.file-url" }),
                  let string = String(data: rep.data, encoding: .utf8) else { return nil }
            return URL(string: string)
        }
    }

    var openLabel: String? {
        switch kind {
        case .link:  return "Open"
        case .image: return "Peek"
        case .file:  return fileURLs.count > 1 ? "Reveal" : "Open"
        case .rich:  return "Open"
        default:     return nil
        }
    }

    var matchText: String {
        ((label ?? "") + " " + summary + " " + (content?.textPreview ?? "")).lowercased()
    }
}

struct Toast: Equatable {
    enum Kind { case success, error }
    let text: String
    let kind: Kind
}

/// Everything the popover shows and every action it can take. Reads and
/// writes go through `SlotStorage`, the same files the CLI uses, so a
/// `clipslots save 3` in a terminal shows up here live (see `SlotsWatcher`).
final class SlotsModel: ObservableObject {
    @Published private(set) var slots: [SlotItem] = []
    @Published var selected: Int = 1
    @Published var filter: String = "" {
        didSet { selectFirstVisibleIfNeeded() }
    }
    @Published var peekSlot: Int?
    /// Set by the row's label button so the peek view opens with the label field focused.
    var focusLabelOnPeek = false
    /// True while the peek view's label field has focus, so ⏎ and space
    /// type into it instead of triggering popover shortcuts.
    var labelFieldFocused = false
    @Published var toast: Toast?
    @Published var dragSource: Int?
    @Published var dropTarget: Int?
    @Published var dropIsCopy = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var launchAtLogin = false

    let engine: AppEngine
    let version: String

    /// Wired up by the AppDelegate.
    var closePopover: () -> Void = {}
    var pasteIntoPreviousApp: (Int) -> Void = { _ in }
    var showOnboarding: () -> Void = {}
    var panelDragChanged: () -> Void = {}
    var panelDragEnded: () -> Void = {}
    var resetPanelPosition: () -> Void = {}

    private var watcher: SlotsWatcher?
    private var toastWork: DispatchWorkItem?

    init(engine: AppEngine, version: String) {
        self.engine = engine
        self.version = version
        reload()
        refreshLoginItem()
        watcher = SlotsWatcher { [weak self] in self?.reload() }
        watcher?.start()
    }

    var slotCount: Int { engine.config.slots }
    var usedCount: Int { slots.filter { !$0.isEmpty }.count }
    var keybinds: Config.Keybinds { engine.config.keybinds }

    var visibleSlots: [SlotItem] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return slots }
        return slots.filter { !$0.isEmpty && $0.matchText.contains(q) }
    }

    func slot(_ n: Int) -> SlotItem? { slots.first { $0.number == n } }

    // MARK: - Loading

    func reload() {
        let storage = engine.storage
        let fm = FileManager.default
        var items: [SlotItem] = []
        for n in 1...engine.config.slots {
            let content = storage.getSlot(n)
            let mtime = (try? fm.attributesOfItem(atPath: Paths.slotDirectory(n).path)[.modificationDate]) as? Date
            items.append(Self.makeItem(
                number: n,
                content: content,
                label: storage.getLabel(n),
                locked: storage.isLocked(n),
                updatedAt: content == nil ? nil : mtime,
                canUndo: storage.hasPrev(n) && !storage.isLocked(n)
            ))
        }
        slots = items
        if !items.contains(where: { $0.number == selected }) { selected = 1 }
        refreshAccessibility()
    }

    private static func makeItem(number: Int, content: SlotContent?, label: String?, locked: Bool, updatedAt: Date?, canUndo: Bool) -> SlotItem {
        guard let content = content, !content.isEmpty else {
            return SlotItem(number: number, content: nil, kind: .empty, label: label, locked: locked,
                            updatedAt: nil, summary: "", image: nil, totalBytes: 0, canUndo: canUndo)
        }
        let types = Set(content.items.flatMap { $0.representations.map { $0.typeString } })
        let bytes = content.items.flatMap { $0.representations }.reduce(0) { $0 + $1.data.count }
        var kind: SlotKind
        var image: NSImage?

        if types.contains("public.file-url") {
            kind = .file
        } else if types.contains("public.png") || types.contains("public.tiff") {
            kind = .image
            let reps = content.items.first?.representations ?? []
            if let data = reps.first(where: { $0.typeString == "public.png" })?.data
                ?? reps.first(where: { $0.typeString == "public.tiff" })?.data {
                image = NSImage(data: data)
            }
        } else if types.contains("public.rtf") || types.contains("public.html") {
            kind = .rich
        } else if let text = content.textPreview {
            kind = isLink(text) ? .link : .text
        } else {
            kind = .binary
        }

        let summary: String
        switch kind {
        case .text, .link:
            let text = content.textPreview ?? ""
            summary = String(text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ⏎ ")
                .prefix(240))
        case .image:
            // Richer than the CLI's "[Image]": format, pixel size, bytes.
            let format = types.contains("public.png") ? "PNG" : "TIFF"
            if let rep = image?.representations.first {
                summary = "[Image \(format) \(rep.pixelsWide)×\(rep.pixelsHigh), \(formatBytes(bytes))]"
            } else {
                summary = "[Image \(format), \(formatBytes(bytes))]"
            }
        default:
            summary = content.contentDescription
        }

        return SlotItem(number: number, content: content, kind: kind, label: label, locked: locked,
                        updatedAt: updatedAt, summary: summary, image: image, totalBytes: bytes, canUndo: canUndo)
    }

    private static func formatBytes(_ count: Int) -> String {
        if count < 1024 { return "\(count) B" }
        if count < 1024 * 1024 { return "\(count / 1024) KB" }
        return String(format: "%.1f MB", Double(count) / (1024 * 1024))
    }

    private static func isLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: { $0.isWhitespace }),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host != nil
    }

    // MARK: - Selection

    func select(_ n: Int) {
        selected = n
    }

    func editLabel(_ n: Int) {
        focusLabelOnPeek = true
        peekSlot = n
    }

    func moveSelection(by delta: Int) {
        let visible = visibleSlots.map(\.number)
        guard !visible.isEmpty else { return }
        let index = visible.firstIndex(of: selected) ?? 0
        let next = max(0, min(visible.count - 1, index + delta))
        selected = visible[next]
    }

    private func selectFirstVisibleIfNeeded() {
        let visible = visibleSlots.map(\.number)
        if !visible.contains(selected), let first = visible.first {
            selected = first
        }
    }

    // MARK: - Actions

    func copy(_ n: Int) {
        guard let content = slot(n)?.content else { return }
        guard engine.clipboard.restoreAll(content) else {
            show(.init(text: "couldn't write to the clipboard", kind: .error))
            return
        }
        closePopover()
        CursorHUD.shared.flashCheckmark()
    }

    func paste(_ n: Int) {
        guard slot(n)?.content != nil else { return }
        refreshAccessibility()
        guard accessibilityGranted else {
            show(.init(text: "paste needs Accessibility; copied instead", kind: .error))
            if let content = slot(n)?.content { _ = engine.clipboard.restoreAll(content) }
            showOnboarding()
            return
        }
        pasteIntoPreviousApp(n)
    }

    func open(_ n: Int) {
        guard let item = slot(n), let content = item.content else { return }
        switch item.kind {
        case .link:
            if let url = item.linkURL { NSWorkspace.shared.open(url); closePopover() }
        case .image:
            peekSlot = n
        case .file:
            let urls = item.fileURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
            guard let first = urls.first else {
                show(.init(text: "file no longer exists", kind: .error))
                return
            }
            if urls.count > 1 {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            } else {
                NSWorkspace.shared.open(first)
            }
            closePopover()
        case .rich:
            let reps = content.items.first?.representations ?? []
            if let rtf = reps.first(where: { $0.typeString == "public.rtf" })?.data {
                openTemp(rtf, slot: n, ext: "rtf")
            } else if let html = reps.first(where: { $0.typeString == "public.html" })?.data {
                openTemp(html, slot: n, ext: "html")
            }
        case .text:
            if let text = content.textPreview { openTemp(Data(text.utf8), slot: n, ext: "txt") }
        case .binary, .empty:
            break
        }
    }

    func openImageInPreview(_ n: Int) {
        guard let reps = slot(n)?.content?.items.first?.representations else { return }
        if let png = reps.first(where: { $0.typeString == "public.png" })?.data {
            openTemp(png, slot: n, ext: "png")
        } else if let tiff = reps.first(where: { $0.typeString == "public.tiff" })?.data {
            openTemp(tiff, slot: n, ext: "tiff")
        }
    }

    func saveImageAs(_ n: Int) {
        guard let image = slot(n)?.image,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "slot-\(n).png"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try png.write(to: url, options: .atomic)
                show(.init(text: "saved \(url.lastPathComponent)", kind: .success))
            } catch {
                show(.init(text: error.localizedDescription, kind: .error))
            }
        }
    }

    /// Same temp location as `clipslots open`, so both leave files in one place.
    private func openTemp(_ data: Data, slot n: Int, ext: String) {
        let dir = URL(fileURLWithPath: "/tmp/clipslots-open", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("slot-\(n).\(ext)")
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
            closePopover()
        } catch {
            show(.init(text: error.localizedDescription, kind: .error))
        }
    }

    func toggleLock(_ n: Int) {
        guard let item = slot(n) else { return }
        perform { try self.engine.storage.setLocked(n, locked: !item.locked) }
        show(.init(text: item.locked ? "unlocked slot \(n)" : "locked slot \(n)", kind: .success))
    }

    func setLabel(_ n: Int, _ label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (slot(n)?.label ?? "") else { return }
        perform { try self.engine.storage.setLabel(n, label: trimmed.isEmpty ? nil : trimmed) }
    }

    func clear(_ n: Int) {
        if perform({ try self.engine.storage.clearSlot(n) }) {
            show(.init(text: "cleared slot \(n)", kind: .success))
        }
    }

    func undo(_ n: Int) {
        if perform({ try self.engine.storage.undo(n) }) {
            show(.init(text: "restored slot \(n)", kind: .success))
        }
    }

    func saveClipboard(into n: Int) {
        guard let content = engine.clipboard.captureAll(), !content.isEmpty else {
            show(.init(text: "clipboard is empty", kind: .error))
            return
        }
        if perform({ try self.engine.storage.setSlot(n, content: content) }) {
            show(.init(text: "saved clipboard to slot \(n)", kind: .success))
        }
    }

    /// Drag-and-drop between rows. Onto a filled slot: swap (or copy with ⌥).
    /// Onto an empty slot: move (or copy with ⌥). Locks are respected.
    func drop(from src: Int, onto dst: Int, copy: Bool) {
        defer { dragSource = nil; dropTarget = nil }
        guard src != dst else { return }
        let storage = engine.storage
        let ok: Bool
        if copy {
            ok = perform { try storage.copy(from: src, to: dst) }
            if ok { show(.init(text: "copied \(src) → \(dst)", kind: .success)) }
        } else if storage.isSlotEmpty(dst) {
            ok = perform {
                if storage.isLocked(src) { throw SlotStorageError.slotLocked(src) }
                // copy carries content, age and label; then empty the source.
                try storage.copy(from: src, to: dst)
                try storage.clearSlot(src)
            }
            if ok { show(.init(text: "moved \(src) → \(dst)", kind: .success)) }
        } else {
            ok = perform { try storage.swap(src, dst) }
            if ok { show(.init(text: "swapped \(src) ↔ \(dst)", kind: .success)) }
        }
        if ok { selected = dst }
    }

    @discardableResult
    private func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            reload()
            return true
        } catch {
            reload()
            show(.init(text: Self.message(for: error), kind: .error))
            return false
        }
    }

    /// Short, popover-sized wording. The CLI's messages point at CLI
    /// commands ("Run `clipslots unlock 3`"), which make no sense here.
    private static func message(for error: Error) -> String {
        switch error {
        case SlotStorageError.slotLocked(let n):      return "slot \(n) is locked"
        case SlotStorageError.slotEmpty(let n):       return "slot \(n) is empty"
        case SlotStorageError.noUndoAvailable(let n): return "nothing to undo in slot \(n)"
        case SlotStorageError.sameSlot:               return "pick a different slot"
        default:                                      return error.localizedDescription
        }
    }

    // MARK: - Toast

    func show(_ toast: Toast) {
        toastWork?.cancel()
        self.toast = toast
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    // MARK: - System state

    func refreshAccessibility() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
    }

    func refreshLoginItem() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            show(.init(text: "login item: \(error.localizedDescription)", kind: .error))
        }
        refreshLoginItem()
    }

    func openConfigFile() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", Paths.configFile.path]
        try? process.run()
        closePopover()
    }
}

/// Watches the slots directory so changes from the CLI, the hotkeys or the
/// expiry sweep show up without reopening the popover. Every write ends in
/// an atomic rename of manifest.json, which touches the directory.
final class SlotsWatcher {
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let fd = open(Paths.slotsDirectory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.schedule() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    deinit {
        source?.cancel()
    }
}
