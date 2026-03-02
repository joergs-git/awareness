import Foundation

// MARK: - Event-Level Logging Model
// Records individual blackout events with timestamps, outcomes, and durations.
// This is the data foundation for the Smart Guru adaptive algorithm.

struct MindfulEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval      // Unix epoch UTC
    let weekday: Int                  // 1=Sun...7=Sat (Calendar.current.component)
    let hourOfDay: Int               // 0-23 local time
    let outcome: EventOutcome
    let durationOffered: Double      // Seconds offered to the user
    let durationActual: Double?      // Seconds actually spent (nil if ignored)
    let intervalFromPrevious: Double? // Seconds since last event (nil for first of day)

    /// Create an event with current time context
    static func create(
        outcome: EventOutcome,
        durationOffered: Double,
        durationActual: Double?,
        intervalFromPrevious: Double?
    ) -> MindfulEvent {
        let now = Date()
        let calendar = Calendar.current
        return MindfulEvent(
            id: UUID(),
            timestamp: now.timeIntervalSince1970,
            weekday: calendar.component(.weekday, from: now),
            hourOfDay: calendar.component(.hour, from: now),
            outcome: outcome,
            durationOffered: durationOffered,
            durationActual: durationActual,
            intervalFromPrevious: intervalFromPrevious
        )
    }
}

// MARK: - Event Outcome

enum EventOutcome: String, Codable {
    case completed   // Sat through full duration
    case dismissed   // Tapped to dismiss early
    case ignored     // Notification delivered, never tapped
}

// MARK: - Adaptive State Model
// Shared across iOS and watchOS (watchOS receives state via sync but doesn't run the algorithm)

struct AdaptiveState: Codable {
    var phase: GuruPhase
    var baselineStartDate: TimeInterval
    var currentMinInterval: Double     // Minutes
    var currentMaxInterval: Double     // Minutes
    var currentMinDuration: Double     // Seconds
    var currentMaxDuration: Double     // Seconds
    var lastAdjustmentDate: TimeInterval?
    var adjustmentCount: Int
    var streakCompleted: Int
    var streakIgnored: Int
    var lastDurationIncreaseDate: String? // "yyyy-MM-dd" — prevents multiple increases per day
}

enum GuruPhase: String, Codable {
    case baseline   // First 3 days, collecting data
    case adapting   // Actively adjusting intervals and duration
}
