import ArgumentParser
import Foundation

struct ClipSlots: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clipslots",
        abstract: "Lightweight clipboard slot manager for macOS",
        version: "1.6.0",
        subcommands: [
            Save.self,
            Paste.self,
            List.self,
            Open.self,
            Clear.self,
            Label.self,
            Lock.self,
            Unlock.self,
            Export.self,
            ImportCommand.self,
            Start.self,
            Stop.self,
            Restart.self,
            Status.self,
            ConfigCommand.self,
            Permissions.self,
            Daemon.self
        ]
    )
}

ClipSlots.main()
