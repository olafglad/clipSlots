import ApplicationServices
import ArgumentParser
import Foundation

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check and guide through permission setup"
    )

    mutating func run() throws {
        let accessible = AXIsProcessTrusted()

        print("Accessibility: \(accessible ? "Granted" : "Not granted")")
        print("")

        if accessible {
            print("You're all set! ClipSlots can register global hotkeys.")
        } else {
            print("ClipSlots needs Accessibility permission to register global hotkeys.")
            print("")
            print("To grant permission:")
            print("1. Open System Settings > Privacy & Security > Accessibility")
            print("2. Find \"clipslots\" in the list and toggle it ON")
            print("3. If it's not listed, click \"+\" and add the clipslots binary")
            print("")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"]
            print("Opening System Settings...")
            try? process.run()
            process.waitUntilExit()
        }
    }
}
