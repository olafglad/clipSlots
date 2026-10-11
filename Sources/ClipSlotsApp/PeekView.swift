import AppKit
import ClipSlotsCore
import SwiftUI

/// Full view of one slot: big preview, `list --verbose`-style details,
/// editable label, and the actions that fit the content type.
struct PeekView: View {
    @ObservedObject var model: SlotsModel
    let item: SlotItem
    @State private var labelDraft = ""
    @FocusState private var labelFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.border)
            preview
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .background(previewBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
                .padding(12)

            SectionHeader(title: "Slot \(item.number)")
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)
            details
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)

            if let toast = model.toast {
                StatusStrip(text: Text(toast.text), tint: toast.kind == .success ? Theme.mint : Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            Divider().overlay(Theme.border)
            actions
                .padding(12)
        }
        .onAppear {
            labelDraft = item.label ?? ""
            if model.focusLabelOnPeek {
                model.focusLabelOnPeek = false
                DispatchQueue.main.async { labelFocused = true }
            }
        }
        .onDisappear {
            model.labelFieldFocused = false
            commitLabel()
        }
        .onChange(of: labelFocused) { model.labelFieldFocused = $0 }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                commitLabel()
                model.peekSlot = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("slots").font(Theme.mono(12))
                }
                .foregroundColor(Theme.text)
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.control))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to slots")
            Spacer()
            Keycap(number: item.number)
            Text("esc to close")
                .font(Theme.mono(12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .accessibilityLabel("Slot \(item.number) image preview")
            }
        case .file:
            VStack(spacing: 10) {
                if let first = item.fileURLs.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .frame(width: 72, height: 72)
                    Text(item.fileURLs.count > 1 ? "\(first.lastPathComponent) + \(item.fileURLs.count - 1) more" : first.lastPathComponent)
                        .font(Theme.mono(12.5))
                    Text(first.deletingLastPathComponent().path)
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 16)
                }
            }
        default:
            ScrollView {
                Text(item.content?.textPreview ?? item.summary)
                    .font(Theme.mono(12))
                    .foregroundColor(item.kind == .link ? Theme.link : Theme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        if item.kind == .image {
            Checkerboard().fill(Theme.text.opacity(0.035)).background(Color(hex: 0x271B3B))
        } else {
            Color(hex: 0x271B3B)
        }
    }

    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                key("type"); value(typeText)
            }
            GridRow {
                key("size"); value(sizeText)
            }
            GridRow {
                key("saved"); value(savedText)
            }
            GridRow {
                key("label")
                TextField("add a label…", text: $labelDraft)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(12.5))
                    .foregroundColor(Theme.mint)
                    .focused($labelFocused)
                    .onSubmit(commitLabel)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(labelFocused ? Theme.mint.opacity(0.6) : Theme.text.opacity(0.22),
                                          style: StrokeStyle(lineWidth: 1, dash: labelFocused ? [] : [4, 3]))
                    )
                    .accessibilityLabel("Slot \(item.number) label")
            }
            GridRow {
                key("lock")
                HStack(spacing: 6) {
                    Text(item.locked ? "●" : "○")
                        .foregroundColor(item.locked ? Theme.mint : Theme.textTertiary)
                    Text(item.locked ? "locked" : "unlocked")
                }
                .font(Theme.mono(12.5))
            }
        }
    }

    private func key(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(12.5))
            .foregroundColor(Theme.textSecondary)
            .frame(width: 60, alignment: .leading)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(12.5))
            .lineLimit(1)
    }

    private var typeText: String {
        let types = Set(item.content?.items.flatMap { $0.representations.map { $0.typeString } } ?? [])
        switch item.kind {
        case .image: return types.contains("public.png") ? "image/png" : "image/tiff"
        case .link:  return "link"
        case .text:  return "text"
        case .rich:  return types.contains("public.rtf") ? "rich text (rtf)" : "rich text (html)"
        case .file:  return item.fileURLs.count > 1 ? "\(item.fileURLs.count) files" : "file"
        default:     return "\(types.count) types"
        }
    }

    private var sizeText: String {
        var parts: [String] = []
        if let image = item.image, let rep = image.representations.first {
            parts.append("\(rep.pixelsWide)×\(rep.pixelsHigh)")
        } else if let text = item.content?.textPreview, item.kind != .file {
            parts.append("\(text.count) chars")
        }
        parts.append(AgeText.bytes(item.totalBytes))
        return parts.joined(separator: " · ")
    }

    private var savedText: String {
        guard let date = item.updatedAt else { return "—" }
        let age = AgeText.short(since: date)
        var text = age == "now" ? "just now" : "\(age) ago"
        if let hours = model.engine.config.expire_after_hours {
            if item.locked {
                text += " · never expires"
            } else {
                let remaining = date.addingTimeInterval(TimeInterval(hours) * 3600).timeIntervalSinceNow
                if remaining > 0 {
                    text += " · expires in \(AgeText.short(since: Date().addingTimeInterval(-remaining)))"
                }
            }
        }
        return text
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            ActionButton(title: "Copy", symbol: "doc.on.doc", hint: "⏎", primary: true) {
                model.copy(item.number)
            }
            switch item.kind {
            case .image:
                ActionButton(title: "Preview", symbol: "arrow.up.right.square") {
                    model.openImageInPreview(item.number)
                }
                ActionButton(title: "Save as…", symbol: "square.and.arrow.down") {
                    model.saveImageAs(item.number)
                }
            case .link, .file, .rich, .text:
                ActionButton(title: "Paste", symbol: "doc.on.clipboard") {
                    model.paste(item.number)
                }
                ActionButton(title: "Open", symbol: "arrow.up.right.square") {
                    model.open(item.number)
                }
            default:
                EmptyView()
            }
            ActionButton(title: nil, symbol: item.locked ? "lock.open" : "lock", accessibilityLabel: item.locked ? "Unlock slot" : "Lock slot") {
                model.toggleLock(item.number)
            }
            Spacer(minLength: 0)
        }
    }

    private func commitLabel() {
        model.setLabel(item.number, labelDraft)
    }
}

struct Checkerboard: Shape {
    var size: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cols = Int(ceil(rect.width / size))
        let rows = Int(ceil(rect.height / size))
        for row in 0..<rows {
            for col in 0..<cols where (row + col) % 2 == 0 {
                path.addRect(CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size))
            }
        }
        return path
    }
}
