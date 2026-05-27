import AppKit

enum Feedback {
    private static let queue = DispatchQueue(label: "com.clipslots.feedback", qos: .userInitiated)

    static func playSuccess(config: Config) {
        guard config.feedback == "sound" else { return }
        queue.async {
            guard let sound = NSSound(named: "Pop") else { return }
            sound.stop()
            sound.play()
        }
    }
}
