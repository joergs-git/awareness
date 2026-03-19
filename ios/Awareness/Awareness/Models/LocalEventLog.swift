import Foundation

/// A single mindfulness event from any platform, stored locally on iOS.
/// Captures all data needed for cross-platform analytics and Smart Guru adaptation.
struct LoggedEvent: Codable, Identifiable {
    let id: UUID
    let source: String          // "ios", "macos", "windows", "watchos"
    let startedAt: Date
    let duration: Double        // seconds
    let completed: Bool
    let awarenessScore: Int?    // 0-100 or nil (dismissed/incomplete)
    let hourOfDay: Int          // 0-23, local time at startedAt
    let weekday: Int            // 1=Sun...7=Sat
    let integratedAt: Date      // when this event was recorded locally
}

/// Persistent store for all mindfulness events from all platforms.
/// JSON file in documents directory, 90-day rolling window.
/// Provides aggregated queries for the Smart Guru algorithm and analytics.
final class LocalEventLog: ObservableObject {

    static let shared = LocalEventLog()

    @Published private(set) var events: [LoggedEvent] = []

    private let fileName = "local-event-log.json"
    private let maxAgeDays = 90

    // MARK: - Recording

    /// Record an event from any platform with explicit fields
    func recordFromBlackout(
        startedAt: Date,
        duration: Double,
        completed: Bool,
        awarenessScore: Int?,
        source: String
    ) {
        let calendar = Calendar.current
        let event = LoggedEvent(
            id: UUID(),
            source: source,
            startedAt: startedAt,
            duration: duration,
            completed: completed,
            awarenessScore: awarenessScore,
            hourOfDay: calendar.component(.hour, from: startedAt),
            weekday: calendar.component(.weekday, from: startedAt),
            integratedAt: Date()
        )
        events.append(event)
        pruneAndSave()
    }

    // MARK: - Queries

    /// Events from the last N days
    func recentEvents(days: Int) -> [LoggedEvent] {
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        return events.filter { $0.startedAt >= cutoff }
    }

    /// All non-nil awareness scores from the last N days
    func awarenessScores(days: Int) -> [Int] {
        recentEvents(days: days).compactMap { $0.awarenessScore }
    }

    /// Awareness scores grouped by hour (0-23) from the last N days
    func awarenessScoresByHour(days: Int) -> [Int: [Int]] {
        var result: [Int: [Int]] = [:]
        for event in recentEvents(days: days) {
            if let score = event.awarenessScore {
                result[event.hourOfDay, default: []].append(score)
            }
        }
        return result
    }

    /// Average awareness across all events in the last N days
    func averageAwareness(days: Int) -> Double? {
        let scores = awarenessScores(days: days)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Events from a specific source in the last N days
    func events(for source: String, days: Int) -> [LoggedEvent] {
        recentEvents(days: days).filter { $0.source == source }
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent(fileName)
    }

    private func pruneAndSave() {
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays * 86400))
        events = events.filter { $0.startedAt >= cutoff }
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Awareness LocalEventLog: save failed — \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            events = try JSONDecoder().decode([LoggedEvent].self, from: data)
        } catch {
            print("Awareness LocalEventLog: load failed — \(error.localizedDescription)")
        }
    }

    private init() {
        load()
    }
}
