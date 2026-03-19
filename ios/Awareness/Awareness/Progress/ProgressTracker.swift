import Foundation
import Combine

/// A single day's blackout statistics and awareness scores
struct DayRecord: Codable, Identifiable {
    let date: String       // "yyyy-MM-dd"
    var triggered: Int
    var completed: Int
    var awarenessScores: [Int]  // Individual 0–100 scores for the day
    var sessionDurations: [Double]  // Actual elapsed seconds per session (completed or interrupted)

    var id: String { date }

    // Computed awareness stats
    var awarenessAverage: Double {
        guard !awarenessScores.isEmpty else { return 0 }
        return Double(awarenessScores.reduce(0, +)) / Double(awarenessScores.count)
    }

    var awarenessMedian: Double {
        guard !awarenessScores.isEmpty else { return 0 }
        let sorted = awarenessScores.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return Double(sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return Double(sorted[count / 2])
        }
    }

    var awarenessMin: Int {
        awarenessScores.min() ?? 0
    }

    var awarenessMax: Int {
        awarenessScores.max() ?? 0
    }

    // Backward-compatible decoding: old records with yes/somewhat/no fields are synthesized
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        triggered = try container.decode(Int.self, forKey: .triggered)
        completed = try container.decode(Int.self, forKey: .completed)

        // Try new format first
        if let scores = try container.decodeIfPresent([Int].self, forKey: .awarenessScores), !scores.isEmpty {
            awarenessScores = scores
        } else {
            // Migrate from old yes/somewhat/no fields
            let yes = try container.decodeIfPresent(Int.self, forKey: .yes) ?? 0
            let somewhat = try container.decodeIfPresent(Int.self, forKey: .somewhat) ?? 0
            let no = try container.decodeIfPresent(Int.self, forKey: .no) ?? 0
            var scores: [Int] = []
            scores += Array(repeating: 100, count: yes)
            scores += Array(repeating: 50, count: somewhat)
            scores += Array(repeating: 0, count: no)
            awarenessScores = scores
        }

        sessionDurations = try container.decodeIfPresent([Double].self, forKey: .sessionDurations) ?? []
    }

    init(date: String, triggered: Int, completed: Int, awarenessScores: [Int] = [], sessionDurations: [Double] = []) {
        self.date = date
        self.triggered = triggered
        self.completed = completed
        self.awarenessScores = awarenessScores
        self.sessionDurations = sessionDurations
    }

    // Only encode the new fields (drop yes/somewhat/no)
    private enum CodingKeys: String, CodingKey {
        case date, triggered, completed, awarenessScores, sessionDurations
        // Legacy keys for decoding only
        case yes, somewhat, no
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(triggered, forKey: .triggered)
        try container.encode(completed, forKey: .completed)
        try container.encode(awarenessScores, forKey: .awarenessScores)
        try container.encode(sessionDurations, forKey: .sessionDurations)
    }
}

/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Also tracks post-blackout awareness scores (0–100 continuous scale).
/// Persists to UserDefaults with a rolling 14-day window for daily records.
/// Shared between iOS and watchOS targets via target membership.
final class ProgressTracker: ObservableObject {

    static let shared = ProgressTracker()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lifetimeTriggered       = "progressLifetimeTriggered"
        static let lifetimeCompleted       = "progressLifetimeCompleted"
        static let lifetimeAwarenessSum    = "progressLifetimeAwarenessSum"
        static let lifetimeAwarenessCount  = "progressLifetimeAwarenessCount"
        static let dailyRecords            = "progressDailyRecords"
        // Legacy keys (read-only for migration)
        static let lifetimeYes       = "progressLifetimeYes"
        static let lifetimeSomewhat  = "progressLifetimeSomewhat"
        static let lifetimeNo        = "progressLifetimeNo"
    }

    // MARK: - Published Properties

    @Published private(set) var lifetimeTriggered: Int
    @Published private(set) var lifetimeCompleted: Int
    @Published private(set) var lifetimeAwarenessSum: Int
    @Published private(set) var lifetimeAwarenessCount: Int
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

    /// Today's awareness scores
    var todayAwarenessScores: [Int] {
        dailyRecords.first(where: { $0.date == todayKey() })?.awarenessScores ?? []
    }

    /// Today's median awareness (0–100), or nil if no scores
    var todayMedianAwareness: Double? {
        let record = dailyRecords.first(where: { $0.date == todayKey() })
        guard let r = record, !r.awarenessScores.isEmpty else { return nil }
        return r.awarenessMedian
    }

    /// Lifetime average awareness (0–100)
    var lifetimeAwarenessAverage: Double {
        guard lifetimeAwarenessCount > 0 else { return 0 }
        return Double(lifetimeAwarenessSum) / Double(lifetimeAwarenessCount)
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

    /// Record the user's post-blackout awareness score (0–100)
    func recordAwarenessScore(_ score: Int) {
        let clamped = max(0, min(100, score))
        lifetimeAwarenessSum += clamped
        lifetimeAwarenessCount += 1
        updateTodayRecord { $0.awarenessScores.append(clamped) }
        save()
    }

    // MARK: - Session Duration

    /// Record the actual elapsed duration (seconds) of a breathing session.
    /// Called for both completed and early-dismissed sessions.
    func recordSessionDuration(_ seconds: Double) {
        guard seconds > 0 else { return }
        updateTodayRecord { $0.sessionDurations.append(seconds) }
        save()
    }

    /// All session durations from the last 14 days, flattened in chronological order (oldest first).
    var recentSessionDurations: [Double] {
        last14Days.flatMap { $0.sessionDurations }
    }

    // MARK: - Remote Event Integration (Desktop Sync)

    /// Integrate a single remote desktop event into daily records and lifetime counters.
    /// Called by SyncManager for each event pulled from Supabase.
    func integrateRemoteEvent(date: String, completed: Bool, awarenessScore: Int?) {
        // Every synced event counts as triggered
        lifetimeTriggered += 1
        updateRecord(for: date) { $0.triggered += 1 }

        if completed {
            lifetimeCompleted += 1
            updateRecord(for: date) { $0.completed += 1 }
        }

        if let score = awarenessScore {
            let clamped = max(0, min(100, score))
            lifetimeAwarenessSum += clamped
            lifetimeAwarenessCount += 1
            updateRecord(for: date) { $0.awarenessScores.append(clamped) }
        }

        save()
    }

    /// Get or create a DayRecord for a specific date string and apply a mutation.
    /// Unlike updateTodayRecord, this works for arbitrary dates (remote events may be from past days).
    private func updateRecord(for dateKey: String, _ mutation: (inout DayRecord) -> Void) {
        if let index = dailyRecords.firstIndex(where: { $0.date == dateKey }) {
            mutation(&dailyRecords[index])
        } else {
            var record = DayRecord(date: dateKey, triggered: 0, completed: 0)
            mutation(&record)
            dailyRecords.append(record)
        }
        pruneOldRecords()
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

    // MARK: - WatchConnectivity Sync

    /// Export progress data as a dictionary for WatchConnectivity applicationContext
    func connectivityContext() -> [String: Any] {
        var context: [String: Any] = [:]
        context["progressLifetimeTriggered"] = lifetimeTriggered
        context["progressLifetimeCompleted"] = lifetimeCompleted
        context["progressLifetimeAwarenessSum"] = lifetimeAwarenessSum
        context["progressLifetimeAwarenessCount"] = lifetimeAwarenessCount

        if let data = try? JSONEncoder().encode(dailyRecords),
           let jsonString = String(data: data, encoding: .utf8) {
            context["progressDailyRecords"] = jsonString
        }

        return context
    }

    /// Merge remote progress data received via WatchConnectivity.
    /// Uses max() per-day to avoid double-counting when devices share a coordinated schedule.
    func applyFromConnectivityContext(_ context: [String: Any]) {
        // Decode remote daily records
        var remoteDailies: [DayRecord] = []
        if let jsonString = context["progressDailyRecords"] as? String,
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([DayRecord].self, from: data) {
            remoteDailies = decoded
        }

        guard !remoteDailies.isEmpty else { return }

        // Merge daily records using max() per day to avoid double-counting
        var mergedByDate: [String: DayRecord] = [:]
        for record in dailyRecords {
            mergedByDate[record.date] = record
        }
        for remote in remoteDailies {
            if let existing = mergedByDate[remote.date] {
                // For awareness scores, use the longer array (more scores = more data)
                let mergedScores = existing.awarenessScores.count >= remote.awarenessScores.count
                    ? existing.awarenessScores : remote.awarenessScores
                let mergedDurations = existing.sessionDurations.count >= remote.sessionDurations.count
                    ? existing.sessionDurations : remote.sessionDurations
                mergedByDate[remote.date] = DayRecord(
                    date: remote.date,
                    triggered: max(existing.triggered, remote.triggered),
                    completed: max(existing.completed, remote.completed),
                    awarenessScores: mergedScores,
                    sessionDurations: mergedDurations
                )
            } else {
                mergedByDate[remote.date] = remote
            }
        }

        dailyRecords = mergedByDate.values.sorted { $0.date < $1.date }
        pruneOldRecords()

        // Recalculate lifetime from merged dailies to stay consistent
        lifetimeTriggered = max(
            lifetimeTriggered,
            context["progressLifetimeTriggered"] as? Int ?? 0
        )
        lifetimeCompleted = max(
            lifetimeCompleted,
            context["progressLifetimeCompleted"] as? Int ?? 0
        )
        lifetimeAwarenessSum = max(
            lifetimeAwarenessSum,
            context["progressLifetimeAwarenessSum"] as? Int ?? 0
        )
        lifetimeAwarenessCount = max(
            lifetimeAwarenessCount,
            context["progressLifetimeAwarenessCount"] as? Int ?? 0
        )

        save()
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
        defaults.set(lifetimeAwarenessSum, forKey: Keys.lifetimeAwarenessSum)
        defaults.set(lifetimeAwarenessCount, forKey: Keys.lifetimeAwarenessCount)

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

        // Try new keys first, then migrate from old yes/somewhat/no
        let storedSum = defaults.integer(forKey: Keys.lifetimeAwarenessSum)
        let storedCount = defaults.integer(forKey: Keys.lifetimeAwarenessCount)

        if storedCount > 0 || storedSum > 0 {
            lifetimeAwarenessSum = storedSum
            lifetimeAwarenessCount = storedCount
        } else {
            // Migrate from old keys: yes*100 + somewhat*50 + no*0
            let oldYes = defaults.integer(forKey: Keys.lifetimeYes)
            let oldSomewhat = defaults.integer(forKey: Keys.lifetimeSomewhat)
            let oldNo = defaults.integer(forKey: Keys.lifetimeNo)
            if oldYes > 0 || oldSomewhat > 0 || oldNo > 0 {
                lifetimeAwarenessSum = oldYes * 100 + oldSomewhat * 50
                lifetimeAwarenessCount = oldYes + oldSomewhat + oldNo
            } else {
                lifetimeAwarenessSum = 0
                lifetimeAwarenessCount = 0
            }
        }

        dailyRecords = []

        // Load daily records after init to avoid property access before initialization
        dailyRecords = loadDailyRecords()
        pruneOldRecords()

        // Persist migrated values if migration occurred
        if storedCount == 0 && storedSum == 0 && (lifetimeAwarenessSum > 0 || lifetimeAwarenessCount > 0) {
            save()
        }
    }
}
