import Foundation
import WidgetKit

// MARK: - Widget Data Bridge
// Writes a snapshot of app state to shared UserDefaults (App Group) so the
// iOS home screen widget can display card, micro-task, donut, and next time
// without needing direct access to SettingsManager or ProgressTracker.

/// Codable snapshot of the data the widget needs to render
struct WidgetSnapshot: Codable {
    let cardID: String
    let cardTitle: String
    let cardShortTitle: String
    let cardColorR: Double
    let cardColorG: Double
    let cardColorB: Double
    let microTaskText: String
    let nextBlackoutTimestamp: Double   // Unix timestamp, 0 if unknown
    let todayTriggered: Int
    let todayCompleted: Int
    let isSnoozed: Bool
    let snoozeUntilTimestamp: Double    // Unix timestamp, 0 if not snoozed
    let lastUpdated: Double            // Unix timestamp
}

/// Bridge between the main iOS app and the widget extension via App Group shared UserDefaults
final class WidgetDataBridge {
    static let shared = WidgetDataBridge()

    /// App Group identifier shared between the iOS app and its widget extension
    static let appGroupID = "group.com.joergsflow.awareness.ios"

    private let snapshotKey = "widgetSnapshot"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetDataBridge.appGroupID)
    }

    private init() {}

    // MARK: - Write (iOS app side)

    /// Update the widget snapshot with current app state and reload widget timelines
    func updateWidget() {
        let settings = SettingsManager.shared
        let progress = ProgressTracker.shared

        // Get today's card and micro-task
        guard let card = settings.todaysPracticeCard() else { return }
        let task = settings.currentMicroTask()

        // Resolve card color RGB components
        let (r, g, b) = cardColorComponents(card.id)

        // Find the next blackout time from either foreground scheduler or notifications
        let nextDates = [
            NotificationScheduler.shared.nextNotificationDate,
            ForegroundScheduler.shared.nextBlackoutDate
        ].compactMap { $0 }
        let nextTimestamp = nextDates.min()?.timeIntervalSince1970 ?? 0

        let snapshot = WidgetSnapshot(
            cardID: card.id,
            cardTitle: card.localizedTitle,
            cardShortTitle: card.localizedShortTitle,
            cardColorR: r,
            cardColorG: g,
            cardColorB: b,
            microTaskText: task?.localizedText ?? card.localizedPrompt,
            nextBlackoutTimestamp: nextTimestamp,
            todayTriggered: progress.todayTriggered,
            todayCompleted: progress.todayCompleted,
            isSnoozed: settings.isSnoozed,
            snoozeUntilTimestamp: settings.snoozeUntil?.timeIntervalSince1970 ?? 0,
            lastUpdated: Date().timeIntervalSince1970
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            sharedDefaults?.set(data, forKey: snapshotKey)
        }

        // Tell WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (widget extension side)

    /// Read the latest snapshot written by the iOS app
    func readSnapshot() -> WidgetSnapshot? {
        guard let data = sharedDefaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // MARK: - Card Color Lookup

    /// Returns RGB components for a card ID (hardcoded to avoid importing SwiftUI in the bridge)
    private func cardColorComponents(_ cardID: String) -> (Double, Double, Double) {
        switch cardID {
        case "letting-go":           return (0.65, 0.42, 0.58)
        case "non-intervention":     return (0.48, 0.52, 0.68)
        case "undivided-perception": return (0.40, 0.38, 0.72)
        case "unhurried-response":   return (0.62, 0.42, 0.62)
        case "intentionlessness":    return (0.56, 0.45, 0.70)
        case "presence-daily-life":  return (0.58, 0.38, 0.55)
        case "silence":              return (0.48, 0.46, 0.62)
        default:                     return (0.55, 0.38, 0.72)
        }
    }
}
