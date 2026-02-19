import ArgumentParser
import Foundation

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check and guide through permission setup"
    )

    mutating func run() throws {
        let status = Clipboard().permissionStatus

        print("Pasteboard Permission: \(status.description)")
        print("")

        switch status {
        case .denied:
            print("ClipSlots needs permission to read your clipboard.")
            print("")
            print("To grant permission:")
            print("1. Open System Settings > Privacy & Security > Pasteboard")
            print("2. Find \"ClipSlots\" in the list")
            print("3. Toggle it ON")
            print("")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard"]
            print("Opening System Settings...")
            try? process.run()
            process.waitUntilExit()

        case .promptEachTime:
            print("ClipSlots will prompt for permission each time it accesses the clipboard.")
            print("For a better experience, grant \"Always Allow\" in System Settings.")

        case .allowed:
            print("Permission granted! ClipSlots can access the clipboard.")

        case .unknown:
            print("Could not determine permission status.")
        }
    }
}
