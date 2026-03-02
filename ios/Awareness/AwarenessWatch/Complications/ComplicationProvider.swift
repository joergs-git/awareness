import WidgetKit
import SwiftUI

/// Timeline provider for Awareness watch complications.
/// Shows the yin-yang symbol with today's progress counter and status info.
struct AwarenessTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AwarenessEntry {
        AwarenessEntry(
            date: Date(),
            nextBlackout: nil,
            isSnoozed: false,
            snoozeUntil: nil,
            todayCompleted: 0,
            todayTriggered: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AwarenessEntry) -> Void) {
        let settings = SettingsManager.shared
        let tracker = ProgressTracker.shared
        let entry = AwarenessEntry(
            date: Date(),
            nextBlackout: nil,
            isSnoozed: settings.isSnoozed,
            snoozeUntil: settings.snoozeUntil,
            todayCompleted: tracker.todayCompleted,
            todayTriggered: tracker.todayTriggered
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AwarenessEntry>) -> Void) {
        let settings = SettingsManager.shared
        let tracker = ProgressTracker.shared
        let now = Date()

        let entry = AwarenessEntry(
            date: now,
            nextBlackout: nil,
            isSnoozed: settings.isSnoozed,
            snoozeUntil: settings.snoozeUntil,
            todayCompleted: tracker.todayCompleted,
            todayTriggered: tracker.todayTriggered
        )

        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

/// Timeline entry containing the state for the complication display
struct AwarenessEntry: TimelineEntry {
    let date: Date
    let nextBlackout: Date?
    let isSnoozed: Bool
    let snoozeUntil: Date?
    let todayCompleted: Int
    let todayTriggered: Int
}

// MARK: - Complication Views

/// Circular complication — yin-yang icon with today's progress counter overlay
struct AccessoryCircularView: View {
    let entry: AwarenessEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image("YinYang")
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .opacity(entry.todayTriggered > 0 ? 0.5 : 1.0)

            // Progress counter overlay (e.g. "2/5")
            if entry.todayTriggered > 0 {
                Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

/// Rectangular complication — "Awareness" + progress counter + next time / snoozed status
struct AccessoryRectangularView: View {
    let entry: AwarenessEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(String(localized: "Awareness reminder"))
                    .font(.headline)
                    .widgetAccentable()
                Spacer()
                if entry.todayTriggered > 0 {
                    Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            if entry.isSnoozed {
                if let until = entry.snoozeUntil, until < Date.distantFuture {
                    Text(String(localized: "Snoozed until \(formatTime(until))"))
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(String(localized: "Snoozed"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if let next = entry.nextBlackout {
                Text(String(localized: "Next: \(formatTime(next))"))
                    .font(.caption)
            } else {
                Text(String(localized: "Active"))
                    .font(.caption)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Inline complication — "☯ 2/5 Next HH:mm" or "☯ Active"
struct AccessoryInlineView: View {
    let entry: AwarenessEntry

    var body: some View {
        if entry.isSnoozed {
            Text(String(localized: "☯ Snoozed"))
        } else if entry.todayTriggered > 0 {
            if let next = entry.nextBlackout {
                Text("☯ \(entry.todayCompleted)/\(entry.todayTriggered) \(formatTime(next))")
            } else {
                Text("☯ \(entry.todayCompleted)/\(entry.todayTriggered)")
            }
        } else if let next = entry.nextBlackout {
            Text(String(localized: "☯ Next \(formatTime(next))"))
        } else {
            Text(String(localized: "☯ Active"))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Entry view that switches layout based on the widget family
struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AwarenessEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            AccessoryRectangularView(entry: entry)
        }
    }
}

// MARK: - Practice Card Complication

/// Timeline entry for the practice card complication
struct PracticeEntry: TimelineEntry {
    let date: Date
    let cardTitle: String?
    let microTaskText: String?
}

/// Timeline provider for the practice card complication.
/// Shows today's practice card title and current micro-task suggestion.
struct PracticeTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PracticeEntry {
        PracticeEntry(
            date: Date(),
            cardTitle: "Exercise of Letting Go",
            microTaskText: "Notice the urge to check for a reply. Don't check."
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PracticeEntry) -> Void) {
        let settings = SettingsManager.shared
        let card = settings.todaysPracticeCard()
        let task = settings.currentMicroTask()
        completion(PracticeEntry(
            date: Date(),
            cardTitle: card?.localizedShortTitle,
            microTaskText: task?.localizedText
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeEntry>) -> Void) {
        let settings = SettingsManager.shared
        let card = settings.todaysPracticeCard()
        let task = settings.currentMicroTask()
        let now = Date()

        let entry = PracticeEntry(
            date: now,
            cardTitle: card?.localizedShortTitle,
            microTaskText: task?.localizedText
        )

        // Refresh every 30 minutes (card changes daily, task changes after blackouts)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: now)!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

/// Rectangular complication showing today's practice card title and micro-task
struct PracticeRectangularView: View {
    let entry: PracticeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = entry.cardTitle {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .widgetAccentable()
            } else {
                Text(String(localized: "No practice today"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            if let task = entry.microTaskText {
                Text(task)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Widget Definitions

/// Status complication — yin-yang icon, progress counter, next time, snooze status
struct AwarenessComplicationWidget: Widget {
    let kind = "AwarenessComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AwarenessTimelineProvider()) { entry in
            if #available(watchOS 10.0, *) {
                ComplicationEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ComplicationEntryView(entry: entry)
            }
        }
        .configurationDisplayName(String(localized: "Awareness reminder"))
        .description(String(localized: "Shows your next mindful moment and today's progress."))
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

/// Practice card complication — today's card title + micro-task in a larger rectangular slot
struct AwarenessPracticeWidget: Widget {
    let kind = "AwarenessPractice"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PracticeTimelineProvider()) { entry in
            if #available(watchOS 10.0, *) {
                PracticeRectangularView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PracticeRectangularView(entry: entry)
            }
        }
        .configurationDisplayName(String(localized: "Today's Practice"))
        .description(String(localized: "Shows today's mindfulness card and micro-task."))
        .supportedFamilies([
            .accessoryRectangular
        ])
    }
}

/// Widget bundle combining both complications into one extension
@main
struct AwarenessWidgetBundle: WidgetBundle {
    var body: some Widget {
        AwarenessComplicationWidget()
        AwarenessPracticeWidget()
    }
}
