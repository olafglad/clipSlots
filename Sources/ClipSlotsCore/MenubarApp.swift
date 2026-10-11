import AppKit

/// Facts about ClipSlots.app shared by the app and the CLI. When the app
/// is running it owns the global hotkeys, so the CLI daemon must stay off
/// (two processes registering the same Carbon hotkeys would collide).
public enum MenubarApp {
    public static let bundleIdentifier = "dev.clipslots.ClipSlots"

    /// The running ClipSlots.app instance, if any (excluding this process).
    public static func runningInstance() -> NSRunningApplication? {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != me && !$0.isTerminated }
    }

    public static var isRunning: Bool { runningInstance() != nil }

    public static let takeoverMessage = """
        ClipSlots.app is running and already handles the hotkeys.
        Quit it from the menubar icon first if you want the CLI daemon instead.
        """
}
