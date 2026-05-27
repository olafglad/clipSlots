import ArgumentParser
import Foundation

struct ClipSlots: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clipslots",
        abstract: "Lightweight clipboard slot manager for macOS",
        version: "1.12.0",
        subcommands: [
            Save.self,
            Paste.self,
            Peek.self,
            List.self,
            Open.self,
            Clear.self,
            Label.self,
            Lock.self,
            Unlock.self,
            Undo.self,
            Swap.self,
            Copy.self,
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
