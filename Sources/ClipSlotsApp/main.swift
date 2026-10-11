import AppKit

#if DEBUG
// `ClipSlotsApp --snapshot <dir>` renders the popover states to PNGs with
// live slot data and exits. Dev-only aid for checking layout without
// clicking through the menubar.
if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
    MainActor.assumeIsolated { Snapshot.run(outputDirectory: CommandLine.arguments[index + 1]) }
    exit(0)
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
