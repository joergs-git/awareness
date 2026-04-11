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

// MARK: - Yin-Yang Symbol

/// SwiftUI-drawn yin-yang that renders correctly in all WidgetKit rendering modes.
///
/// In watchOS vibrant mode, ONLY the alpha channel determines brightness — RGB values
/// are completely ignored. All fully-opaque pixels render at the same brightness.
/// Therefore the dark dot cannot be created by overlaying any color on top of the
/// opaque white half (the result is always alpha 1.0 = bright).
///
/// Solution: use a Canvas to clip the bright half so the dot area is never drawn,
/// letting the 0.35-alpha dark background show through as a visibly dimmer dot.
private struct YinYangSymbol: View {
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        let darkFill: Color = renderingMode == .fullColor ? .black : .white.opacity(0.35)
        let brightFill: Color = .white

        Canvas { context, size in
            let dim = min(size.width, size.height)
            let r = dim / 2
            let cx = size.width / 2
            let cy = size.height / 2
            let dotR = dim * 0.12

            // Rects for the two dots
            let darkDotRect = CGRect(x: cx - dotR, y: cy + r / 2 - dotR,
                                     width: dotR * 2, height: dotR * 2)
            let brightDotRect = CGRect(x: cx - dotR, y: cy - r / 2 - dotR,
                                       width: dotR * 2, height: dotR * 2)
            let outerRect = CGRect(x: cx - r, y: cy - r, width: dim, height: dim)

            // 1. Dark background circle (alpha 0.35 in vibrant mode)
            context.fill(Path(ellipseIn: outerRect), with: .color(darkFill))

            // 2. Bright S-curve half, clipped to EXCLUDE the dark dot area.
            //    The clip uses a full rect with the dot circle subtracted via even-odd fill.
            //    This way the dot area is never painted white — the dark background shows through.
            context.drawLayer { ctx in
                var clipPath = Path()
                clipPath.addRect(CGRect(origin: .zero, size: size))
                clipPath.addEllipse(in: darkDotRect)
                ctx.clip(to: clipPath, style: FillStyle(eoFill: true))

                var halfPath = Path()
                halfPath.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                startAngle: .degrees(-90), endAngle: .degrees(90),
                                clockwise: false)
                halfPath.addArc(center: CGPoint(x: cx, y: cy + r / 2), radius: r / 2,
                                startAngle: .degrees(90), endAngle: .degrees(270),
                                clockwise: true)
                halfPath.addArc(center: CGPoint(x: cx, y: cy - r / 2), radius: r / 2,
                                startAngle: .degrees(90), endAngle: .degrees(270),
                                clockwise: false)
                halfPath.closeSubpath()
                ctx.fill(halfPath, with: .color(brightFill))
            }

            // 3. Bright dot in dark half's head (alpha 1.0 on alpha 0.35 = visible)
            context.fill(Path(ellipseIn: brightDotRect), with: .color(brightFill))
        }
        .clipShape(Circle())
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Complication Views

/// Circular complication — yin-yang icon with today's progress counter overlay
struct AccessoryCircularView: View {
    let entry: AwarenessEntry

    var body: some View {
        ZStack {
            YinYangSymbol()
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
                Text(String(localized: "Atempause"))
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
/// Uses storedPracticeCard() (read-only) to avoid assigning a different random card
/// than what iOS synced — iOS is the leader for card assignment.
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
        // Prefer storedPracticeCard (read-only, respects iOS sync) with
        // todaysPracticeCard fallback so a card is always shown
        let card = settings.storedPracticeCard() ?? settings.todaysPracticeCard()
        let task = settings.currentMicroTask()
        // When no micro-task yet (before first blackout), show card prompt as fallback
        let subtitle = task?.localizedText ?? card?.localizedPrompt
        completion(PracticeEntry(
            date: Date(),
            cardTitle: card?.localizedShortTitle,
            microTaskText: subtitle
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeEntry>) -> Void) {
        let settings = SettingsManager.shared
        let card = settings.storedPracticeCard() ?? settings.todaysPracticeCard()
        let task = settings.currentMicroTask()
        let subtitle = task?.localizedText ?? card?.localizedPrompt
        let now = Date()

        let entry = PracticeEntry(
            date: now,
            cardTitle: card?.localizedShortTitle,
            microTaskText: subtitle
        )

        // Refresh every 30 minutes (card changes daily, task syncs from iOS after blackout)
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
        .configurationDisplayName(String(localized: "Atempause"))
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
