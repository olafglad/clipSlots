import AppKit
import SwiftUI

/// Brand palette from the landing page's dark theme (docs/css/index.css):
/// purple body, mint accent. Mint plays the role cyan plays in the CLI
/// (section headers, labels); purple marks selection and primary actions.
enum Theme {
    static let background = Color(hex: 0x1E1430)
    static let backgroundNS = NSColor(srgbRed: 0x1E / 255, green: 0x14 / 255, blue: 0x30 / 255, alpha: 1)
    static let raised = Color(hex: 0x33254D)
    static let thumb = Color(hex: 0x2E2245)

    static let text = Color(hex: 0xF0EBF5)
    static let textSecondary = Color(hex: 0xF0EBF5).opacity(0.68)
    static let textTertiary = Color(hex: 0xF0EBF5).opacity(0.55)
    static let surface = Color(hex: 0xF0EBF5).opacity(0.05)
    static let control = Color(hex: 0xF0EBF5).opacity(0.06)
    static let controlHover = Color(hex: 0xF0EBF5).opacity(0.12)
    static let border = Color(hex: 0xF0EBF5).opacity(0.10)
    static let borderStrong = Color(hex: 0xF0EBF5).opacity(0.16)

    static let accent = Color(hex: 0x8B5FBF)
    static let accentHover = Color(hex: 0x9E75CF)
    static let accentLight = Color(hex: 0xB794E6)
    static let accentLighter = Color(hex: 0xD2BBF2)
    static let link = Color(hex: 0xC9A9F0)
    static let mint = Color(hex: 0x7DDFB0)
    static let danger = Color(hex: 0xF4A3B8)

    static let selectionFill = Color(hex: 0x8B5FBF).opacity(0.16)
    static let selectionBorder = Color(hex: 0xB794E6).opacity(0.40)

    // MARK: - Type

    private static var fontRegistered = false

    /// Registers the bundled JetBrains Mono (same face as the landing page).
    /// Falls back to the system monospaced font if the file is missing,
    /// e.g. when running the bare binary outside the .app bundle.
    static func registerFonts() {
        guard !fontRegistered else { return }
        fontRegistered = true
        guard let url = Bundle.main.url(forResource: "JetBrainsMono", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static let hasJetBrains: Bool = {
        registerFonts()
        return NSFont(name: "JetBrains Mono", size: 12) != nil
    }()

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if hasJetBrains {
            return Font.custom("JetBrains Mono", size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Template image for the menubar: a clipboard with a small slot grid,
/// drawn in code so it stays crisp and follows the menubar's tint.
enum MenubarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let board = NSBezierPath(roundedRect: NSRect(x: 3.25, y: 3, width: 11.5, height: 13.25), xRadius: 2, yRadius: 2)
            board.lineWidth = 1.5
            board.stroke()

            let clip = NSBezierPath(roundedRect: NSRect(x: 6.25, y: 1.5, width: 5.5, height: 3), xRadius: 1, yRadius: 1)
            clip.fill()

            for row in 0..<2 {
                for col in 0..<2 {
                    let cell = NSRect(x: 5.75 + CGFloat(col) * 4, y: 7.25 + CGFloat(row) * 4, width: 2.5, height: 2.5)
                    NSBezierPath(roundedRect: cell, xRadius: 0.5, yRadius: 0.5).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ClipSlots"
        return image
    }
}
