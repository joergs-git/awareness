import Foundation

// MARK: - Event Store
// Persistent store for MindfulEvent data with 90-day rolling window.
// Provides aggregated profiles for the Smart Guru algorithm.

class EventStore: ObservableObject {
    static let shared = EventStore()

    // MARK: - Storage Keys

    private enum Keys {
        static let events = "eventStoreEvents"
        static let hourProfile = "eventStoreHourProfile"
        static let lastEventTimestamp = "eventStoreLastEventTimestamp"
    }

    // MARK: - Properties

    /// All events within the 90-day rolling window
    @Published private(set) var events: [MindfulEvent] = []

    /// Cumulative engaged counts per hour (24 buckets: [completed, engagedTotal]).
    /// Only completed/dismissed events are counted — `.ignored` (phone left unattended)
    /// is deliberately excluded so an idle device can't poison the time-of-day signal.
    private var hourProfile: [[Int]] = Array(repeating: [0, 0], count: 24)

    // MARK: - Init

    private init() {
        loadEvents()
        loadProfiles()
    }

    // MARK: - Recording

    /// Record a new mindful event and update profiles
    func record(event: MindfulEvent) {
        events.append(event)

        // Update hour profile — engaged events only (completed + dismissed).
        // `.ignored` notifications are NOT counted: they usually mean the user was
        // simply away from the device, not that they rejected the break.
        if event.outcome != .ignored {
            let hour = event.hourOfDay
            hourProfile[hour][1] += 1
            if event.outcome == .completed {
                hourProfile[hour][0] += 1
            }
        }

        // Store timestamp of last event for interval calculation
        UserDefaults.standard.set(event.timestamp, forKey: Keys.lastEventTimestamp)

        pruneAndSave()
    }

    // MARK: - Queries

    /// Events from the last N days
    func recentEvents(days: Int) -> [MindfulEvent] {
        let cutoff = Date().timeIntervalSince1970 - Double(days * 86400)
        return events.filter { $0.timestamp >= cutoff }
    }

    /// Overall success rate for recent events (includes ignored in denominator).
    /// Used for user-facing stats, NOT for guru frequency decisions.
    func successRate(days: Int) -> Double {
        let recent = recentEvents(days: days)
        guard !recent.isEmpty else { return 0.0 }
        let completed = recent.filter { $0.outcome == .completed }.count
        return Double(completed) / Double(recent.count)
    }

    /// Success rate over *engaged* events only — completed / (completed + dismissed).
    /// `.ignored` is excluded so a phone left unattended cannot drag the rate down and
    /// make the Smart Guru mute itself. Returns nil when there are no engaged events in
    /// the window (caller should hold, not adapt).
    func engagedSuccessRate(days: Int) -> Double? {
        let engaged = recentEvents(days: days).filter { $0.outcome != .ignored }
        guard !engaged.isEmpty else { return nil }
        let completed = engaged.filter { $0.outcome == .completed }.count
        return Double(completed) / Double(engaged.count)
    }

    /// Success rate for a specific hour (±1 hour window from cumulative profile)
    func hourlySuccessRate(hour: Int) -> Double? {
        // Include hour-1, hour, hour+1 for smoothing
        var completed = 0
        var total = 0
        for offset in -1...1 {
            let h = (hour + offset + 24) % 24
            completed += hourProfile[h][0]
            total += hourProfile[h][1]
        }
        guard total >= 10 else { return nil } // Not enough data
        return Double(completed) / Double(total)
    }

    /// Timestamp of the most recent event (for interval calculation)
    var lastEventTimestamp: TimeInterval? {
        let stored = UserDefaults.standard.double(forKey: Keys.lastEventTimestamp)
        return stored > 0 ? stored : nil
    }

    /// Count of consecutive outcomes from most recent events
    func consecutiveOutcome(_ outcome: EventOutcome) -> Int {
        var count = 0
        for event in events.reversed() {
            if event.outcome == outcome {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// Rolling awareness average from the last N events that have awareness scores
    func rollingAwarenessAverage(last n: Int) -> Double? {
        let scores = events.reversed().compactMap { $0.awarenessScore }.prefix(n)
        guard scores.count >= 3 else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Total engaged-event count in the hour profile for a given hour (data sufficiency check)
    func hourProfileTotal(hour: Int) -> Int {
        var total = 0
        for offset in -1...1 {
            let h = (hour + offset + 24) % 24
            total += hourProfile[h][1]
        }
        return total
    }

    // MARK: - Persistence

    private func pruneAndSave() {
        // 90-day rolling window
        let cutoff = Date().timeIntervalSince1970 - Double(90 * 86400)
        events = events.filter { $0.timestamp >= cutoff }
        saveEvents()
        saveProfiles()
    }

    private func saveEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Keys.events)
        }
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: Keys.events),
              let decoded = try? JSONDecoder().decode([MindfulEvent].self, from: data) else { return }
        events = decoded
    }

    private func saveProfiles() {
        if let hourData = try? JSONEncoder().encode(hourProfile) {
            UserDefaults.standard.set(hourData, forKey: Keys.hourProfile)
        }
    }

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: Keys.hourProfile),
           let decoded = try? JSONDecoder().decode([[Int]].self, from: data),
           decoded.count == 24 {
            hourProfile = decoded
        }
    }

}
