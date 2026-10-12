import AppKit

public enum Feedback {
    private static let queue = DispatchQueue(label: "com.clipslots.feedback", qos: .userInitiated)

    public enum Event { case save, append, paste }

    /// Set by ClipSlots.app to draw its checkmark next to the pointer. The
    /// CLI daemon has no UI, so "visual" is a no-op there.
    public static var visualHandler: (() -> Void)?

    /// Confirms a hotkey action per `config.feedback`: "sound" plays Pop on
    /// every action; "visual" flashes the checkmark on save/append (a paste
    /// is its own confirmation); "both" does both.
    public static func playSuccess(config: Config, event: Event) {
        let mode = config.feedback
        if mode == "sound" || mode == "both" {
            queue.async {
                guard let sound = NSSound(named: "Pop") else { return }
                sound.stop()
                sound.play()
            }
        }
        if (mode == "visual" || mode == "both") && event != .paste, let handler = visualHandler {
            DispatchQueue.main.async(execute: handler)
        }
    }
}
