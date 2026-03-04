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
        static let weekdayProfile = "eventStoreWeekdayProfile"
        static let selfReports = "eventStoreSelfReports"
        static let lastEventTimestamp = "eventStoreLastEventTimestamp"
    }

    // MARK: - Properties

    /// All events within the 90-day rolling window
    @Published private(set) var events: [MindfulEvent] = []

    /// Cumulative success counts per hour (24 buckets: [completed, total])
    private var hourProfile: [[Int]] = Array(repeating: [0, 0], count: 24)

    /// Cumulative success counts per weekday (7 buckets: [completed, total])
    /// Index 0 = Sunday, 6 = Saturday
    private var weekdayProfile: [[Int]] = Array(repeating: [0, 0], count: 7)

    /// Archived daily self-reports
    @Published private(set) var selfReports: [DailySelfReport] = []

    // MARK: - Init

    private init() {
        loadEvents()
        loadProfiles()
        loadSelfReports()
    }

    // MARK: - Recording

    /// Record a new mindful event and update profiles
    func record(event: MindfulEvent) {
        events.append(event)

        // Update hour profile
        let hour = event.hourOfDay
        hourProfile[hour][1] += 1
        if event.outcome == .completed {
            hourProfile[hour][0] += 1
        }

        // Update weekday profile (weekday is 1-based: 1=Sun)
        let weekdayIndex = event.weekday - 1
        weekdayProfile[weekdayIndex][1] += 1
        if event.outcome == .completed {
            weekdayProfile[weekdayIndex][0] += 1
        }

        // Store timestamp of last event for interval calculation
        UserDefaults.standard.set(event.timestamp, forKey: Keys.lastEventTimestamp)

        pruneAndSave()
    }

    /// Archive a daily self-report (called on day change)
    func archiveSelfReport(_ report: DailySelfReport) {
        selfReports.append(report)
        // Keep last 90 days of reports
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoff)
        selfReports = selfReports.filter { $0.date >= cutoffString }
        saveSelfReports()
    }

    // MARK: - Queries

    /// Events from the last N days
    func recentEvents(days: Int) -> [MindfulEvent] {
        let cutoff = Date().timeIntervalSince1970 - Double(days * 86400)
        return events.filter { $0.timestamp >= cutoff }
    }

    /// Overall success rate for recent events
    func successRate(days: Int) -> Double {
        let recent = recentEvents(days: days)
        guard !recent.isEmpty else { return 0.0 }
        let completed = recent.filter { $0.outcome == .completed }.count
        return Double(completed) / Double(recent.count)
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

    /// Success rate for a specific weekday from cumulative profile
    func weekdaySuccessRate(weekday: Int) -> Double? {
        let index = weekday - 1 // Convert 1-based to 0-based
        guard index >= 0, index < 7 else { return nil }
        let total = weekdayProfile[index][1]
        guard total >= 5 else { return nil }
        return Double(weekdayProfile[index][0]) / Double(total)
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

    /// Average actual duration for recent completed events
    func averageCompletedDuration(days: Int) -> Double? {
        let recent = recentEvents(days: days)
            .filter { $0.outcome == .completed && $0.durationActual != nil }
        guard !recent.isEmpty else { return nil }
        let total = recent.compactMap { $0.durationActual }.reduce(0, +)
        return total / Double(recent.count)
    }

    /// Count of dismissed events in recent history
    func dismissedCount(days: Int) -> Int {
        recentEvents(days: days).filter { $0.outcome == .dismissed }.count
    }

    /// Total event count in the hour profile for a given hour (for data sufficiency checks)
    func hourProfileTotal(hour: Int) -> Int {
        var total = 0
        for offset in -1...1 {
            let h = (hour + offset + 24) % 24
            total += hourProfile[h][1]
        }
        return total
    }

    // MARK: - WatchConnectivity Sync

    /// Export archived self-reports for cross-device sync via applicationContext
    func selfReportConnectivityContext() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(selfReports),
              let json = String(data: data, encoding: .utf8) else { return [:] }
        return ["archivedSelfReports": json]
    }

    /// Merge remote archived self-reports using max per field per date.
    /// Prevents double-counting when the same blackout is counted on both devices.
    func applyFromSelfReportContext(_ context: [String: Any]) {
        guard let json = context["archivedSelfReports"] as? String,
              let data = json.data(using: .utf8),
              let remote = try? JSONDecoder().decode([DailySelfReport].self, from: data) else { return }

        var lookup: [String: DailySelfReport] = [:]
        for r in selfReports { lookup[r.date] = r }

        for r in remote {
            if let existing = lookup[r.date] {
                lookup[r.date] = DailySelfReport(
                    date: r.date,
                    cardID: existing.cardID.isEmpty ? r.cardID : existing.cardID,
                    succeeded: max(existing.succeeded, r.succeeded),
                    noticed: max(existing.noticed, r.noticed),
                    forgot: max(existing.forgot, r.forgot)
                )
            } else {
                lookup[r.date] = r
            }
        }

        selfReports = lookup.values.sorted { $0.date < $1.date }
        saveSelfReports()
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
        if let weekdayData = try? JSONEncoder().encode(weekdayProfile) {
            UserDefaults.standard.set(weekdayData, forKey: Keys.weekdayProfile)
        }
    }

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: Keys.hourProfile),
           let decoded = try? JSONDecoder().decode([[Int]].self, from: data),
           decoded.count == 24 {
            hourProfile = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Keys.weekdayProfile),
           let decoded = try? JSONDecoder().decode([[Int]].self, from: data),
           decoded.count == 7 {
            weekdayProfile = decoded
        }
    }

    private func saveSelfReports() {
        if let data = try? JSONEncoder().encode(selfReports) {
            UserDefaults.standard.set(data, forKey: Keys.selfReports)
        }
    }

    private func loadSelfReports() {
        guard let data = UserDefaults.standard.data(forKey: Keys.selfReports),
              let decoded = try? JSONDecoder().decode([DailySelfReport].self, from: data) else { return }
        selfReports = decoded
    }
}

// MARK: - Daily Self-Report

struct DailySelfReport: Codable, Identifiable {
    let date: String           // "yyyy-MM-dd"
    let cardID: String         // Which practice card was active
    var succeeded: Int         // checkmark counter
    var noticed: Int           // eye counter
    var forgot: Int            // circle counter

    var id: String { date }
}
