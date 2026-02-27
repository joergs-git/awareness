import WatchKit

/// Plays haptic feedback on Apple Watch using the Taptic Engine.
/// Uses multi-tap patterns to create distinctive haptic signatures that
/// stand out from ordinary watchOS notifications.
struct HapticPlayer {

    /// Play a gentle multi-tap haptic at the start of a blackout.
    /// 3× success pulses with 0.4s gaps — feels like a calm invitation to pause.
    static func playStart() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                WKInterfaceDevice.current().play(.success)
            }
        }
    }

    /// Play a distinctive multi-tap haptic at the end of a blackout.
    /// 4× notification pulses with 0.3s gaps — feels like a deliberate wake-up signal.
    static func playEnd() {
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}
