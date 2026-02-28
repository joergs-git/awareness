import WatchKit

/// Plays haptic feedback on Apple Watch using the Taptic Engine.
/// Uses multi-tap patterns to create distinctive haptic signatures:
/// - Reminder: attention-grabbing pulse when a notification arrives
/// - End: uplifting signal when a blackout finishes
struct HapticPlayer {

    /// Play a reminder haptic when a notification arrives.
    /// 2× failure pulses with 0.4s gaps — a firm nudge to pay attention.
    static func playReminder() {
        for i in 0..<2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    /// Play a completion haptic at the end of a blackout.
    /// 2× directionUp pulses with 0.3s gaps — an uplifting "all done" signal.
    static func playEnd() {
        for i in 0..<2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                WKInterfaceDevice.current().play(.directionUp)
            }
        }
    }
}
