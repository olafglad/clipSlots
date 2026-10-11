import AppKit
import SwiftUI

/// Boxed slot number, like a key cap: `[3]`.
struct Keycap: View {
    let number: Int
    var empty = false
    var highlighted = false

    var body: some View {
        Text("\(number)")
            .font(Theme.mono(13, .bold))
            .foregroundColor(highlighted ? Theme.mint : (empty ? Theme.textTertiary : Theme.accentLighter))
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(highlighted ? Theme.mint.opacity(0.14) : (empty ? Color.clear : Theme.accent.opacity(0.18)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        highlighted ? Theme.mint : (empty ? Theme.text.opacity(0.30) : Theme.accentLight.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 1, dash: empty && !highlighted ? [2.5, 2] : [])
                    )
            )
    }
}

/// `SLOTS ─────────── 6 used · 3 free`, the GUI twin of the CLI's
/// `Style.sectionHeader`.
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(Theme.mono(11, .bold))
                .tracking(1)
                .foregroundColor(Theme.mint)
            Rectangle()
                .fill(Theme.mint.opacity(0.25))
                .frame(height: 1)
            if let trailing = trailing {
                Text(trailing)
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
}

struct ActionButton: View {
    let title: String?
    let symbol: String
    var hint: String?
    var primary = false
    var accessibilityLabel: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                if let title = title {
                    Text(title)
                        .font(Theme.mono(12, primary ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize()
                }
                if let hint = hint {
                    Text(hint)
                        .font(Theme.mono(12))
                        .opacity(0.75)
                }
            }
            .foregroundColor(primary ? .white : Theme.text)
            .padding(.horizontal, title == nil ? 0 : (primary ? 11 : 10))
            .frame(minWidth: 32, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(primary ? (hovering ? Theme.accentHover : Theme.accent) : (hovering ? Theme.controlHover : Theme.control))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(primary ? Color.clear : Theme.text.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(accessibilityLabel ?? title ?? "")
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text.opacity(0.75))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Theme.controlHover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
    }
}

/// Status strip above the footer: toasts and the live drag hint.
struct StatusStrip: View {
    let text: Text
    var tint: Color = Theme.mint
    var trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            Text("❯")
                .font(Theme.mono(12, .bold))
                .foregroundColor(tint)
            text
                .font(Theme.mono(12))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let trailing = trailing {
                Text(trailing)
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }
}

enum Mascot {
    static let image: NSImage? = Bundle.main.image(forResource: "mascot")
}

enum KeybindText {
    /// "ctrl+option+{n}" → "⌃⌥1–9"; "ctrl+option+v" → "⌃⌥V".
    static func pretty(_ pattern: String, slots: Int) -> String {
        let parts = pattern.split(separator: "+").map { String($0).lowercased() }
        var out = ""
        for part in parts {
            switch part {
            case "ctrl", "control":  out += "⌃"
            case "option", "alt":    out += "⌥"
            case "shift":            out += "⇧"
            case "cmd", "command":   out += "⌘"
            case "{n}":              out += slots > 1 ? "1–\(min(slots, 9))" : "1"
            case "space":            out += "Space"
            default:                 out += part.uppercased()
            }
        }
        return out
    }
}

enum AgeText {
    static func short(since date: Date?, now: Date = Date()) -> String {
        guard let date = date else { return "" }
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "now" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        if h < 24 { return "\(h)h" }
        return "\(h / 24)d"
    }

    static func bytes(_ count: Int) -> String {
        if count < 1024 { return "\(count) B" }
        if count < 1024 * 1024 { return "\(count / 1024) KB" }
        return String(format: "%.1f MB", Double(count) / (1024 * 1024))
    }
}

/// Left-to-right layout that wraps to a new line when the row is full,
/// like CSS `flex-wrap: wrap`. Keeps the inline action buttons readable
/// at the popover's fixed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
