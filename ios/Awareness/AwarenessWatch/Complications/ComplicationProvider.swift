import WidgetKit
import SwiftUI

/// Timeline provider for Awareness watch complications.
/// Shows the ☯ symbol with status tint and the next blackout time.
struct AwarenessTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AwarenessEntry {
        AwarenessEntry(date: Date(), nextBlackout: nil, isSnoozed: false, snoozeUntil: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AwarenessEntry) -> Void) {
        let settings = SettingsManager.shared
        let entry = AwarenessEntry(
            date: Date(),
            nextBlackout: nil,
            isSnoozed: settings.isSnoozed,
            snoozeUntil: settings.snoozeUntil
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AwarenessEntry>) -> Void) {
        let settings = SettingsManager.shared
        let now = Date()

        let entry = AwarenessEntry(
            date: now,
            nextBlackout: nil,
            isSnoozed: settings.isSnoozed,
            snoozeUntil: settings.snoozeUntil
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
}

// MARK: - Complication Views

/// Circular complication — ☯ symbol with green/orange tint
struct AccessoryCircularView: View {
    let entry: AwarenessEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "yinyang")
                .font(.title2)
                .foregroundColor(entry.isSnoozed ? .orange : .green)
        }
    }
}

/// Rectangular complication — "Awareness" + next time / snoozed status
struct AccessoryRectangularView: View {
    let entry: AwarenessEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Awareness")
                .font(.headline)
                .widgetAccentable()
            if entry.isSnoozed {
                if let until = entry.snoozeUntil, until < Date.distantFuture {
                    Text("Snoozed until \(formatTime(until))")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Snoozed")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if let next = entry.nextBlackout {
                Text("Next: \(formatTime(next))")
                    .font(.caption)
            } else {
                Text("Active")
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

/// Inline complication — "Awareness ☯ Next HH:mm"
struct AccessoryInlineView: View {
    let entry: AwarenessEntry

    var body: some View {
        if entry.isSnoozed {
            Text("Awareness ☯ Snoozed")
        } else if let next = entry.nextBlackout {
            Text("Awareness ☯ Next \(formatTime(next))")
        } else {
            Text("Awareness ☯ Active")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Widget Definition

/// WidgetKit widget for watch face complications.
/// Entry point for the AwarenessWatchComplication widget extension target.
@main
struct AwarenessComplicationWidget: Widget {
    let kind = "AwarenessComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AwarenessTimelineProvider()) { entry in
            if #available(watchOS 10.0, *) {
                complicationView(for: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                complicationView(for: entry)
            }
        }
        .configurationDisplayName("Awareness")
        .description("Shows your next mindful moment.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }

    @ViewBuilder
    private func complicationView(for entry: AwarenessEntry) -> some View {
        AccessoryRectangularView(entry: entry)
    }
}
