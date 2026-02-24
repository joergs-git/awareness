import WatchKit

/// Plays haptic feedback on Apple Watch using the Taptic Engine.
/// Wraps WKInterfaceDevice.current().play() for blackout start/end events.
struct HapticPlayer {

    /// Play a haptic at the start of a blackout (strong tap)
    static func playStart() {
        WKInterfaceDevice.current().play(.start)
    }

    /// Play a haptic at the end of a blackout (success confirmation)
    static func playEnd() {
        WKInterfaceDevice.current().play(.success)
    }
}
