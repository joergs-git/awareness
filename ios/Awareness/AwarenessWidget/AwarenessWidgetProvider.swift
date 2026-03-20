import WidgetKit
import SwiftUI

// MARK: - Widget Snapshot (mirrors WidgetDataBridge.WidgetSnapshot from the iOS app)
// Defined separately here so the widget extension doesn't depend on iOS app code.

struct WidgetSnapshotData: Codable {
    let cardID: String
    let cardTitle: String
    let cardShortTitle: String
    let cardColorR: Double
    let cardColorG: Double
    let cardColorB: Double
    let microTaskText: String
    let nextBlackoutTimestamp: Double
    let todayTriggered: Int
    let todayCompleted: Int
    let isSnoozed: Bool
    let snoozeUntilTimestamp: Double
    let lastUpdated: Double
}

// MARK: - Timeline Entry

/// Data snapshot for a single widget timeline entry
struct AwarenessWidgetEntry: TimelineEntry {
    let date: Date
    let cardTitle: String
    let cardShortTitle: String
    let cardColor: Color
    let microTaskText: String
    let nextBlackoutDate: Date?
    let todayTriggered: Int
    let todayCompleted: Int
    let isSnoozed: Bool

    /// Placeholder entry for widget gallery and loading states
    static let placeholder = AwarenessWidgetEntry(
        date: Date(),
        cardTitle: "Exercise of Letting Go",
        cardShortTitle: "Letting Go",
        cardColor: Color(red: 0.77, green: 0.58, blue: 0.42),
        microTaskText: "Notice the urge to check for a reply. Don't check. Just notice.",
        nextBlackoutDate: Date().addingTimeInterval(900),
        todayTriggered: 5,
        todayCompleted: 3,
        isSnoozed: false
    )
}

// MARK: - Timeline Provider

/// Provides timeline entries by reading the shared WidgetSnapshot from App Group UserDefaults
struct AwarenessWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> AwarenessWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AwarenessWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AwarenessWidgetEntry>) -> Void) {
        let entry = currentEntry()

        // Refresh every 15 minutes to keep "next blackout" time current
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    /// Build an entry from the shared snapshot written by the iOS app
    private func currentEntry() -> AwarenessWidgetEntry {
        guard let snapshot = readSnapshot() else {
            return .placeholder
        }

        let nextDate: Date? = snapshot.nextBlackoutTimestamp > 0
            ? Date(timeIntervalSince1970: snapshot.nextBlackoutTimestamp)
            : nil

        return AwarenessWidgetEntry(
            date: Date(),
            cardTitle: snapshot.cardTitle,
            cardShortTitle: snapshot.cardShortTitle,
            cardColor: Color(
                red: snapshot.cardColorR,
                green: snapshot.cardColorG,
                blue: snapshot.cardColorB
            ),
            microTaskText: snapshot.microTaskText,
            nextBlackoutDate: nextDate,
            todayTriggered: snapshot.todayTriggered,
            todayCompleted: snapshot.todayCompleted,
            isSnoozed: snapshot.isSnoozed
        )
    }

    /// Read the snapshot from shared UserDefaults written by the iOS app
    private func readSnapshot() -> WidgetSnapshotData? {
        guard let defaults = UserDefaults(suiteName: "group.com.joergsflow.awareness.ios"),
              let data = defaults.data(forKey: "widgetSnapshot") else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetSnapshotData.self, from: data)
    }
}

// MARK: - Widget Definition

/// iOS home screen + lock screen widget showing practice card, micro-task, and progress
struct AwarenessHomeWidget: Widget {
    let kind: String = "AwarenessHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AwarenessWidgetProvider()) { entry in
            AwarenessWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Awareness")
        .description("Today's practice card, micro-task, and mindful moments progress.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Widget Views

/// Main widget view that routes to the appropriate layout for each widget family.
/// Home screen: warm sunrise gradient background. Lock screen: system-tinted monochrome.
struct AwarenessWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AwarenessWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
                .awarenessWidgetBackground()
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .awarenessWidgetBackground()
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
                .awarenessWidgetBackground()
        }
    }
}

// MARK: - Widget Background Helper

extension View {
    /// Apply the warm gradient as the widget background, adaptive for light/dark mode.
    /// iOS 17+: uses containerBackground so the gradient fills the entire rounded rect.
    /// iOS 16: falls back to a plain background behind the content.
    @ViewBuilder
    func awarenessWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                WidgetWarmBackground()
            }
        } else {
            self.background(WidgetWarmBackground())
        }
    }
}

/// Warm gradient background for widgets, adaptive to light/dark mode.
/// Separate from WarmBackground since the widget extension can't share iOS app code.
private struct WidgetWarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.14, green: 0.10, blue: 0.20),
                   Color(red: 0.09, green: 0.07, blue: 0.14)]
                : [Color(red: 0.94, green: 0.91, blue: 0.98),
                   Color(red: 0.88, green: 0.84, blue: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Medium Widget

/// Layout:
/// ┌──────────────────────────────────────────────┐
/// │ ▌ Card Title (up to 2 lines)      ◉ 2/5     │
/// │ ▌                                            │
/// │ ▌ "Micro-task italic text that               │
/// │ ▌  can span multiple lines..."               │
/// │ ▌ [ ☯ Breathe ]          Next 14:32          │
/// └──────────────────────────────────────────────┘
struct MediumWidgetView: View {
    let entry: AwarenessWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left color strip from card
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.cardColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                // Top: card title (wraps to 2 lines) + compact donut
                HStack(alignment: .top, spacing: 6) {
                    Text(entry.cardTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    // Compact donut + counter
                    VStack(spacing: 2) {
                        WidgetDonut(
                            completed: entry.todayCompleted,
                            triggered: entry.todayTriggered,
                            color: entry.cardColor,
                            size: 18
                        )
                        Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Middle: micro-task text (full, multi-line)
                Text(entry.microTaskText)
                    .font(.caption2.italic())
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // Bottom: next time left, breathe button right
                HStack {
                    // Next blackout time or snoozed
                    if let nextDate = entry.nextBlackoutDate, !entry.isSnoozed {
                        HStack(spacing: 3) {
                            Text("Next:")
                                .font(.caption2)
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatTime(nextDate))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    } else if entry.isSnoozed {
                        HStack(spacing: 3) {
                            Image(systemName: "moon.fill")
                                .font(.caption2)
                            Text("Snoozed")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }

                    Spacer()

                    // Breathe now button (deep link)
                    Link(destination: URL(string: "awareness://breathe")!) {
                        HStack(spacing: 4) {
                            Text("☯")
                                .font(.caption)
                            Text("Breathe")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(entry.cardColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(entry.cardColor, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.leading, 10)
        }
        // Tapping anywhere except the Breathe button just opens the app
        .widgetURL(URL(string: "awareness://open"))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Small Widget (donut + next time + card accent)

/// Layout:
/// ┌────────────────────┐
/// │       ☯            │
/// │    ◉ donut         │
/// │      2/5           │
/// │   Next 14:32       │
/// │ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ │
/// │  card color accent │
/// └────────────────────┘
struct SmallWidgetView: View {
    let entry: AwarenessWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 2)

            // Yin-yang symbol
            Text("☯")
                .font(.title2)

            // Progress donut
            WidgetDonut(
                completed: entry.todayCompleted,
                triggered: entry.todayTriggered,
                color: entry.cardColor,
                size: 36
            )

            // Counter text
            Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundColor(.secondary)

            // Next time or snoozed
            if let nextDate = entry.nextBlackoutDate, !entry.isSnoozed {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatTime(nextDate))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            } else if entry.isSnoozed {
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(.caption2)
                    Text("Snoozed")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }

            Spacer(minLength: 2)

            // Card color accent bar at bottom
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.cardColor)
                .frame(height: 4)
                .padding(.horizontal, 12)
        }
        // Small widget: tap opens app (systemSmall doesn't support Link)
        .widgetURL(URL(string: "awareness://open"))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen: Circular (donut with counter)

/// Compact circular widget for the lock screen showing today's progress donut.
/// ┌─────┐
/// │ ◉   │
/// │ 3/5 │
/// └─────┘
struct AccessoryCircularView: View {
    let entry: AwarenessWidgetEntry

    private var ratio: Double {
        guard entry.todayTriggered > 0 else { return 0 }
        return min(Double(entry.todayCompleted) / Double(entry.todayTriggered), 1.0)
    }

    var body: some View {
        ZStack {
            // Background ring
            AccessoryWidgetBackground()

            // Progress arc
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
                .widgetAccentable()

            // Center counter
            VStack(spacing: 0) {
                Text("☯")
                    .font(.caption2)
                Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
        }
    }
}

// MARK: - Lock Screen: Rectangular (card title + next time)

/// Rectangular widget for the lock screen showing card short title and next blackout time.
/// ┌────────────────────────────┐
/// │ ☯ Letting Go               │
/// │ Next: 14:32 · 3/5          │
/// └────────────────────────────┘
struct AccessoryRectangularView: View {
    let entry: AwarenessWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text("☯")
                    .font(.caption2)
                Text(entry.cardTitle)
                    .font(.caption)
                    .lineLimit(2)
                    .widgetAccentable()
            }

            HStack(spacing: 4) {
                if let nextDate = entry.nextBlackoutDate, !entry.isSnoozed {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(formatTime(nextDate))
                            .font(.caption2)
                    }
                } else if entry.isSnoozed {
                    HStack(spacing: 2) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 9))
                        Text("Snoozed")
                            .font(.caption2)
                    }
                }

                Text("·")
                    .font(.system(size: 9))

                Text("\(entry.todayCompleted)/\(entry.todayTriggered)")
                    .font(.caption2.monospacedDigit())
            }
            .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen: Inline (text only)

/// Single-line inline widget for the lock screen.
/// Displays: "☯ 3/5 · Letting Go" or "☯ Snoozed"
struct AccessoryInlineView: View {
    let entry: AwarenessWidgetEntry

    var body: some View {
        if entry.isSnoozed {
            Text("☯ Snoozed")
        } else {
            Text("☯ \(entry.todayCompleted)/\(entry.todayTriggered) · \(entry.cardShortTitle)")
        }
    }
}

// MARK: - Widget Donut

/// Miniature donut chart showing completion ratio
struct WidgetDonut: View {
    let completed: Int
    let triggered: Int
    let color: Color
    let size: CGFloat

    private var ratio: Double {
        guard triggered > 0 else { return 0 }
        return min(Double(completed) / Double(triggered), 1.0)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: size * 0.15)

            // Progress arc
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

struct AwarenessWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AwarenessWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            AwarenessWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
