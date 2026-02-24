import Foundation

/// Represents the daily active time window during which blackouts may occur.
/// Hours are in 24-hour format (0-23).
struct TimeWindow: Equatable {
    var startHour: Int   // e.g. 8 for 08:00
    var endHour: Int     // e.g. 19 for 19:00

    /// Check whether the current time falls within this window
    func isCurrentlyActive() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if startHour <= endHour {
            // Normal range, e.g. 08:00-19:00
            return hour >= startHour && hour < endHour
        } else {
            // Overnight range, e.g. 22:00-06:00
            return hour >= startHour || hour < endHour
        }
    }
}
