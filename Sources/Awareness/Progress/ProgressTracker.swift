import Foundation
import Combine

/// A single day's blackout statistics
struct DayRecord: Codable, Identifiable {
    let date: String       // "yyyy-MM-dd"
    var triggered: Int
    var completed: Int

    var id: String { date }
}

/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Persists to UserDefaults with a rolling 14-day window for daily records.
final class ProgressTracker: ObservableObject {

    static let shared = ProgressTracker()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lifetimeTriggered = "progressLifetimeTriggered"
        static let lifetimeCompleted = "progressLifetimeCompleted"
        static let dailyRecords      = "progressDailyRecords"
    }

    // MARK: - Published Properties

    @Published private(set) var lifetimeTriggered: Int
    @Published private(set) var lifetimeCompleted: Int
    @Published private(set) var dailyRecords: [DayRecord]

    // MARK: - Computed Properties

    /// Number of blackouts triggered today
    var todayTriggered: Int {
        dailyRecords.first(where: { $0.date == todayKey() })?.triggered ?? 0
    }

    /// Number of blackouts completed today (full duration)
    var todayCompleted: Int {
        dailyRecords.first(where: { $0.date == todayKey() })?.completed ?? 0
    }

    /// Lifetime success rate (0.0 to 1.0)
    var successRate: Double {
        guard lifetimeTriggered > 0 else { return 0 }
        return Double(lifetimeCompleted) / Double(lifetimeTriggered)
    }

    /// Last 14 days of records, padded with zero-count days for any missing dates
    var last14Days: [DayRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [DayRecord] = []

        for offset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = dateKey(for: date)
            if let existing = dailyRecords.first(where: { $0.date == key }) {
                result.append(existing)
            } else {
                result.append(DayRecord(date: key, triggered: 0, completed: 0))
            }
        }

        return result
    }

    // MARK: - Recording

    /// Record that a blackout was triggered (screen appeared)
    func recordTriggered() {
        lifetimeTriggered += 1
        updateTodayRecord { $0.triggered += 1 }
        save()
    }

    /// Record that a blackout completed its full duration (auto-dismiss timer fired)
    func recordCompleted() {
        lifetimeCompleted += 1
        updateTodayRecord { $0.completed += 1 }
        save()
    }

    // MARK: - Review Prompt

    /// Milestones at which to prompt for App Store review
    private static let reviewMilestones = [30, 50, 100]
    private let reviewMilestonesShownKey = "progressReviewMilestonesShown"

    /// Check if a new review milestone was just reached.
    /// Returns true once per milestone (30, 50, 100 completed breaks).
    func shouldRequestReview() -> Bool {
        let shown = Set(defaults.array(forKey: reviewMilestonesShownKey) as? [Int] ?? [])
        for milestone in Self.reviewMilestones {
            if lifetimeCompleted >= milestone && !shown.contains(milestone) {
                var updated = shown
                updated.insert(milestone)
                defaults.set(Array(updated), forKey: reviewMilestonesShownKey)
                return true
            }
        }
        return false
    }

    // MARK: - Private Helpers

    /// Get or create today's record and apply a mutation
    private func updateTodayRecord(_ mutation: (inout DayRecord) -> Void) {
        let key = todayKey()
        if let index = dailyRecords.firstIndex(where: { $0.date == key }) {
            mutation(&dailyRecords[index])
        } else {
            var record = DayRecord(date: key, triggered: 0, completed: 0)
            mutation(&record)
            dailyRecords.append(record)
        }
        pruneOldRecords()
    }

    /// Remove records older than 14 days
    private func pruneOldRecords() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: Date()))!
        let cutoffKey = dateKey(for: cutoff)
        dailyRecords.removeAll { $0.date < cutoffKey }
    }

    /// Format today's date as "yyyy-MM-dd"
    private func todayKey() -> String {
        dateKey(for: Date())
    }

    /// Format a date as "yyyy-MM-dd"
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(lifetimeTriggered, forKey: Keys.lifetimeTriggered)
        defaults.set(lifetimeCompleted, forKey: Keys.lifetimeCompleted)

        if let data = try? JSONEncoder().encode(dailyRecords) {
            defaults.set(data, forKey: Keys.dailyRecords)
        }
    }

    private func loadDailyRecords() -> [DayRecord] {
        guard let data = defaults.data(forKey: Keys.dailyRecords),
              let records = try? JSONDecoder().decode([DayRecord].self, from: data) else {
            return []
        }
        return records
    }

    // MARK: - Init

    private init() {
        lifetimeTriggered = defaults.integer(forKey: Keys.lifetimeTriggered)
        lifetimeCompleted = defaults.integer(forKey: Keys.lifetimeCompleted)
        dailyRecords = []

        // Load daily records after init to avoid property access before initialization
        dailyRecords = loadDailyRecords()
        pruneOldRecords()
    }
}
