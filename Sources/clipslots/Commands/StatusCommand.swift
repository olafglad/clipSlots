import ApplicationServices
import ArgumentParser
import Foundation

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show daemon status and configuration",
        discussion: """
            Example:
              clipslots status

            Renders a fastfetch-style layout with logo + sections in a wide
            color TTY, and stacks plain text when piped or under NO_COLOR=1.
            """
    )

    mutating func run() throws {
        let report = gather()
        let sectionLines = renderSections(report)
        let logo = verticallyCentered(colorizedLogo(), toHeight: sectionLines.count)
        let output = Layout.render(logo: logo, sections: sectionLines)
        print(output)
    }

    /// Pad a logo with blank lines top and bottom so it sits vertically
    /// centered against a taller sections column. No-op if the logo is
    /// already as tall as (or taller than) the target.
    private func verticallyCentered(_ logo: [String], toHeight target: Int) -> [String] {
        guard target > logo.count else { return logo }
        let extra = target - logo.count
        let top = extra / 2
        let bottom = extra - top
        return Array(repeating: "", count: top) + logo + Array(repeating: "", count: bottom)
    }

    // MARK: - Data

    private struct Report {
        var daemonRunning: Bool
        var daemonPID: Int?
        var daemonUptime: TimeInterval?
        var accessibilityGranted: Bool
        var pasteboardAllowed: Bool
        var slotsConfigured: Int
        var slotsUsed: Int
        var slotsLocked: Int
        var keybinds: Config.Keybinds
    }

    private func gather() -> Report {
        let config = (try? ConfigManager.load()) ?? Config.default
        let clipboard = Clipboard()
        let (running, pid) = LaunchAgentManager.isRunning()

        let uptime: TimeInterval? = {
            guard running, let pid = pid else { return nil }
            return LaunchAgentManager.uptimeForPID(pid)
        }()

        let storage = try? SlotStorage(slotCount: config.slots)
        let used = storage.map { s in
            (1...config.slots).filter { !s.isSlotEmpty($0) }.count
        } ?? 0
        let locked = storage?.lockedSlots().count ?? 0

        return Report(
            daemonRunning: running,
            daemonPID: pid,
            daemonUptime: uptime,
            accessibilityGranted: AXIsProcessTrusted(),
            pasteboardAllowed: clipboard.permissionStatus.isUsable,
            slotsConfigured: config.slots,
            slotsUsed: used,
            slotsLocked: locked,
            keybinds: config.keybinds
        )
    }

    // MARK: - Rendering

    private func colorizedLogo() -> [String] {
        logoLines.map { Style.color(.magenta, $0) }
    }

    private func renderSections(_ r: Report) -> [String] {
        let keyWidth = 14
        var lines: [String] = []

        // Daemon
        lines.append(Style.sectionHeader("Daemon"))
        lines.append(Style.keyValue("Status:", "\(Style.indicator(on: r.daemonRunning)) \(r.daemonRunning ? "Running" : "Not running")", keyWidth: keyWidth))
        if r.daemonRunning, let pid = r.daemonPID {
            lines.append(Style.keyValue("PID:", String(pid), keyWidth: keyWidth))
        }
        if let uptime = r.daemonUptime {
            lines.append(Style.keyValue("Uptime:", formatUptime(uptime), keyWidth: keyWidth))
        }
        lines.append("")

        // Permissions
        lines.append(Style.sectionHeader("Permissions"))
        lines.append(Style.keyValue("Accessibility:", "\(Style.indicator(on: r.accessibilityGranted)) \(r.accessibilityGranted ? "Granted" : "Not granted")", keyWidth: keyWidth))
        lines.append(Style.keyValue("Pasteboard:", "\(Style.indicator(on: r.pasteboardAllowed)) \(r.pasteboardAllowed ? "Allowed" : "Denied")", keyWidth: keyWidth))
        lines.append("")

        // Slots
        lines.append(Style.sectionHeader("Slots"))
        lines.append(Style.keyValue("Configured:", String(r.slotsConfigured), keyWidth: keyWidth))
        lines.append(Style.keyValue("Used:", "\(r.slotsUsed) / \(r.slotsConfigured)", keyWidth: keyWidth))
        lines.append(Style.keyValue("Locked:", String(r.slotsLocked), keyWidth: keyWidth))
        lines.append("")

        // Keybinds
        lines.append(Style.sectionHeader("Keybinds"))
        lines.append(Style.keyValue("Save:", r.keybinds.save, keyWidth: keyWidth))
        lines.append(Style.keyValue("Paste:", r.keybinds.paste, keyWidth: keyWidth))
        let appendDesc = r.keybinds.append.isEmpty ? "off" : r.keybinds.append
        lines.append(Style.keyValue("Append:", appendDesc, keyWidth: keyWidth))

        return lines
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let rem = m % 60
        if h < 24 { return "\(h)h \(rem)m" }
        let d = h / 24
        let hr = h % 24
        return "\(d)d \(hr)h"
    }
}
