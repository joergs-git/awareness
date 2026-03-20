import Foundation

/// Represents the daily active time window during which blackouts may occur.
/// Hours are in 24-hour format (0–23).
struct TimeWindow: Equatable {
    var startHour: Int   // e.g. 8 for 08:00
    var endHour: Int     // e.g. 19 for 19:00

    /// Check whether the current time falls within this window
    func isCurrentlyActive() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if startHour <= endHour {
            // Normal range, e.g. 08:00–19:00
            return hour >= startHour && hour < endHour
        } else {
            // Overnight range, e.g. 22:00–06:00
            return hour >= startHour || hour < endHour
        }
    }

    /// Check whether a specific date falls within this window
    func isActive(at date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        } else {
            return hour >= startHour || hour < endHour
        }
    }

    /// The next time the active window starts, relative to now.
    /// Returns nil if the window is currently active.
    func nextWindowStart() -> Date? {
        guard !isCurrentlyActive() else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        if startHour <= endHour {
            if hour < startHour {
                return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)
            } else {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: tomorrow)
            }
        } else {
            if hour < startHour {
                return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)
            } else {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: tomorrow)
            }
        }
    }
}
