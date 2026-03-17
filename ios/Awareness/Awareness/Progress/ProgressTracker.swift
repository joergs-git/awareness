import Foundation
import Combine

/// Post-blackout awareness response: "Were you there?"
enum AwarenessResponse {
    case yes, somewhat, no
}

/// A single day's blackout statistics and awareness responses
struct DayRecord: Codable, Identifiable {
    let date: String       // "yyyy-MM-dd"
    var triggered: Int
    var completed: Int
    var yes: Int
    var somewhat: Int
    var no: Int

    var id: String { date }

    // Backward-compatible decoding: old records without awareness fields decode as 0
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        triggered = try container.decode(Int.self, forKey: .triggered)
        completed = try container.decode(Int.self, forKey: .completed)
        yes = try container.decodeIfPresent(Int.self, forKey: .yes) ?? 0
        somewhat = try container.decodeIfPresent(Int.self, forKey: .somewhat) ?? 0
        no = try container.decodeIfPresent(Int.self, forKey: .no) ?? 0
    }

    init(date: String, triggered: Int, completed: Int, yes: Int = 0, somewhat: Int = 0, no: Int = 0) {
        self.date = date
        self.triggered = triggered
        self.completed = completed
        self.yes = yes
        self.somewhat = somewhat
        self.no = no
    }
}

/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Also tracks post-blackout awareness responses (yes/somewhat/no).
/// Persists to UserDefaults with a rolling 14-day window for daily records.
/// Shared between iOS and watchOS targets via target membership.
final class ProgressTracker: ObservableObject {

    static let shared = ProgressTracker()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lifetimeTriggered = "progressLifetimeTriggered"
        static let lifetimeCompleted = "progressLifetimeCompleted"
        static let lifetimeYes       = "progressLifetimeYes"
        static let lifetimeSomewhat  = "progressLifetimeSomewhat"
        static let lifetimeNo        = "progressLifetimeNo"
        static let dailyRecords      = "progressDailyRecords"
    }

    // MARK: - Published Properties

    @Published private(set) var lifetimeTriggered: Int
    @Published private(set) var lifetimeCompleted: Int
    @Published private(set) var lifetimeYes: Int
    @Published private(set) var lifetimeSomewhat: Int
    @Published private(set) var lifetimeNo: Int
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

    /// Today's awareness responses
    var todayYes: Int {
        dailyRecords.first(where: { $0.date == todayKey() })?.yes ?? 0
    }

    var todaySomewhat: Int {
        dailyRecords.first(where: { $0.date == todayKey() })?.somewhat ?? 0
    }

    var todayNo: Int {
        dailyRecords.first(where: { $0.date == todayKey() })?.no ?? 0
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

    /// Record the user's post-blackout awareness response
    func recordAwarenessResponse(_ response: AwarenessResponse) {
        switch response {
        case .yes:
            lifetimeYes += 1
            updateTodayRecord { $0.yes += 1 }
        case .somewhat:
            lifetimeSomewhat += 1
            updateTodayRecord { $0.somewhat += 1 }
        case .no:
            lifetimeNo += 1
            updateTodayRecord { $0.no += 1 }
        }
        save()
    }

    // MARK: - Remote Event Integration (Desktop Sync)

    /// Integrate a single remote desktop event into daily records and lifetime counters.
    /// Called by SyncManager for each event pulled from Supabase.
    func integrateRemoteEvent(date: String, completed: Bool, awareness: AwarenessResponse?) {
        // Every synced event counts as triggered
        lifetimeTriggered += 1
        updateRecord(for: date) { $0.triggered += 1 }

        if completed {
            lifetimeCompleted += 1
            updateRecord(for: date) { $0.completed += 1 }
        }

        if let awareness = awareness {
            switch awareness {
            case .yes:
                lifetimeYes += 1
                updateRecord(for: date) { $0.yes += 1 }
            case .somewhat:
                lifetimeSomewhat += 1
                updateRecord(for: date) { $0.somewhat += 1 }
            case .no:
                lifetimeNo += 1
                updateRecord(for: date) { $0.no += 1 }
            }
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
        context["progressLifetimeYes"] = lifetimeYes
        context["progressLifetimeSomewhat"] = lifetimeSomewhat
        context["progressLifetimeNo"] = lifetimeNo

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
                mergedByDate[remote.date] = DayRecord(
                    date: remote.date,
                    triggered: max(existing.triggered, remote.triggered),
                    completed: max(existing.completed, remote.completed),
                    yes: max(existing.yes, remote.yes),
                    somewhat: max(existing.somewhat, remote.somewhat),
                    no: max(existing.no, remote.no)
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
        lifetimeYes = max(
            lifetimeYes,
            context["progressLifetimeYes"] as? Int ?? 0
        )
        lifetimeSomewhat = max(
            lifetimeSomewhat,
            context["progressLifetimeSomewhat"] as? Int ?? 0
        )
        lifetimeNo = max(
            lifetimeNo,
            context["progressLifetimeNo"] as? Int ?? 0
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
        defaults.set(lifetimeYes, forKey: Keys.lifetimeYes)
        defaults.set(lifetimeSomewhat, forKey: Keys.lifetimeSomewhat)
        defaults.set(lifetimeNo, forKey: Keys.lifetimeNo)

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
        lifetimeYes = defaults.integer(forKey: Keys.lifetimeYes)
        lifetimeSomewhat = defaults.integer(forKey: Keys.lifetimeSomewhat)
        lifetimeNo = defaults.integer(forKey: Keys.lifetimeNo)
        dailyRecords = []

        // Load daily records after init to avoid property access before initialization
        dailyRecords = loadDailyRecords()
        pruneOldRecords()
    }
}
