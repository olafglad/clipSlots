import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum AnsiColor {
    case red, green, yellow, blue, magenta, cyan, white

    var code: String {
        switch self {
        case .red:     return "31"
        case .green:   return "32"
        case .yellow:  return "33"
        case .blue:    return "34"
        case .magenta: return "35"
        case .cyan:    return "36"
        case .white:   return "37"
        }
    }
}

enum AnsiAttr {
    case bold, dim

    var code: String {
        switch self {
        case .bold: return "1"
        case .dim:  return "2"
        }
    }
}

enum Style {
    /// Whether ANSI color should be emitted on this stdout.
    /// Honors `NO_COLOR` (force off) and `CLICOLOR_FORCE=1` (force on),
    /// otherwise defaults to `isatty(stdout)`.
    static func useColor() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["CLICOLOR_FORCE"] == "1" { return true }
        if env["NO_COLOR"] != nil { return false }
        return isatty(fileno(stdoutFile)) != 0
    }

    static func color(_ c: AnsiColor, _ text: String) -> String {
        guard useColor() else { return text }
        return "\u{001B}[\(c.code)m\(text)\u{001B}[0m"
    }

    static func attr(_ a: AnsiAttr, _ text: String) -> String {
        guard useColor() else { return text }
        return "\u{001B}[\(a.code)m\(text)\u{001B}[0m"
    }

    static func bold(_ text: String) -> String { attr(.bold, text) }
    static func dim(_ text: String) -> String  { attr(.dim, text) }

    /// Bold cyan title in TTY, plain text otherwise. No trailing newline.
    static func sectionHeader(_ title: String) -> String {
        guard useColor() else { return title }
        return "\u{001B}[1;\(AnsiColor.cyan.code)m\(title)\u{001B}[0m"
    }

    /// `key` padded to `keyWidth` (dim-styled), two spaces, then `value`.
    static func keyValue(_ key: String, _ value: String, keyWidth: Int) -> String {
        let padded = key.padding(toLength: keyWidth, withPad: " ", startingAt: 0)
        return "\(dim(padded))  \(value)"
    }

    /// Semantic state indicator. ● green / ○ red in TTY; [x]/[ ] when piped.
    static func indicator(on: Bool) -> String {
        if useColor() {
            return on ? color(.green, "●") : color(.red, "○")
        }
        return on ? "[x]" : "[ ]"
    }

    /// Visible width of a string after stripping ANSI CSI sequences.
    /// KNOWN-IMPERFECT: counts grapheme clusters; emoji and CJK width-2
    /// characters will report narrower than they actually render. Good
    /// enough for our pure-ASCII section labels.
    static func visibleWidth(_ text: String) -> Int {
        let pattern = "\u{001B}\\[[0-9;]*[A-Za-z]"
        let stripped: String
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        } else {
            stripped = text
        }
        return stripped.count
    }

    /// Terminal width via TIOCGWINSZ, falling back to $COLUMNS, then 80.
    static func terminalColumns() -> Int {
        var w = winsize()
        if ioctl(fileno(stdoutFile), UInt(TIOCGWINSZ), &w) == 0, w.ws_col > 0 {
            return Int(w.ws_col)
        }
        if let cols = ProcessInfo.processInfo.environment["COLUMNS"],
           let n = Int(cols), n > 0 {
            return n
        }
        return 80
    }
}

enum Layout {
    /// Render two columns side-by-side with `gap` spaces between them.
    /// Output line count is `max(left.count, right.count)`; shorter side is padded with blanks.
    static func twoColumn(left: [String], right: [String], gap: Int) -> [String] {
        let leftWidth = left.map { Style.visibleWidth($0) }.max() ?? 0
        let height = max(left.count, right.count)
        var out: [String] = []
        let gapStr = String(repeating: " ", count: gap)
        for i in 0..<height {
            let l = i < left.count ? left[i] : ""
            let r = i < right.count ? right[i] : ""
            let pad = String(repeating: " ", count: max(0, leftWidth - Style.visibleWidth(l)))
            out.append("\(l)\(pad)\(gapStr)\(r)")
        }
        return out
    }

    /// Render a logo + sections block. In a narrow terminal or non-color
    /// output (NO_COLOR, pipe), the logo is omitted and sections are
    /// printed stacked.
    static func render(logo: [String], sections: [String], gap: Int = 4) -> String {
        let logoWidth = logo.map { Style.visibleWidth($0) }.max() ?? 0
        let minSectionsWidth = 40
        let needed = logoWidth + gap + minSectionsWidth

        if !Style.useColor() || Style.terminalColumns() < needed {
            return sections.joined(separator: "\n")
        }
        let lines = twoColumn(left: logo, right: sections, gap: gap)
        return lines.joined(separator: "\n")
    }
}

// Avoid name clash with other files exposing `stdout` at module scope.
private var stdoutFile: UnsafeMutablePointer<FILE> { Darwin.stdout }
