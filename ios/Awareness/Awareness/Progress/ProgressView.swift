import SwiftUI

/// Progress statistics view for iOS showing two donut charts (today + overall),
/// a philosophical slogan, today/lifetime counters, and a 14-day bar chart.
struct ProgressView: View {

    @ObservedObject var tracker = ProgressTracker.shared

    /// Warm earthy color for donut arcs (Chinese sunrise palette)
    private let donutColor = Color(red: 0.72, green: 0.50, blue: 0.38)

    var body: some View {
        List {
            // MARK: - Twin Donut Charts
            Section {
                HStack(spacing: 20) {
                    Spacer()

                    // Today donut
                    VStack(spacing: 8) {
                        brushDonut(
                            rate: todayRate,
                            hasData: tracker.todayTriggered > 0,
                            size: 110,
                            lineWidth: 16
                        )
                        .frame(width: 110, height: 110)

                        Text(String(localized: "Today"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Overall donut
                    VStack(spacing: 8) {
                        brushDonut(
                            rate: tracker.successRate,
                            hasData: tracker.lifetimeTriggered > 0,
                            size: 110,
                            lineWidth: 16
                        )
                        .frame(width: 110, height: 110)

                        Text(String(localized: "Overall"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.top, 8)
                .padding(.bottom, 0)
            }

            // MARK: - Philosophical Slogan
            Section {
                Text(currentSlogan)
                    .font(.callout.italic())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, -4)
                    .listRowBackground(Color.clear)
            }

            // MARK: - Stats
            Section {
                HStack {
                    Text(String(localized: "Today"))
                    Spacer()
                    Text("\(tracker.todayCompleted) \(String(localized: "completed")), \(tracker.todayTriggered) \(String(localized: "triggered"))")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(String(localized: "Lifetime"))
                    Spacer()
                    Text("\(tracker.lifetimeCompleted) \(String(localized: "completed")), \(tracker.lifetimeTriggered) \(String(localized: "triggered"))")
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - 14-Day Bar Chart
            Section {
                barChart
                    .padding(.vertical, 8)
            } header: {
                Text(String(localized: "Breathings"))
            }

            // MARK: - 14-Day Self-Report Chart
            Section {
                selfReportChart
                    .padding(.vertical, 8)
            } header: {
                Text(String(localized: "Situations"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle(String(localized: "Mindful Moments"))
    }

    // MARK: - Brush-Style Donut

    /// A donut chart with a brush-stroke effect: multiple overlapping arcs at slight offsets
    /// create the impression of ink brush irregularity.
    @ViewBuilder
    private func brushDonut(rate: Double, hasData: Bool, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)

            if hasData && rate > 0 {
                // Primary arc
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Brush overlays — semi-transparent arcs at offsets simulate ink brush texture
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth * 0.85, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .offset(x: 1.0, y: -0.8)

                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .offset(x: -0.8, y: 1.2)

                // Third overlay with dashed stroke for subtle texture breaks
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round, dash: [10, 2]))
                    .rotationEffect(.degrees(-90))
                    .offset(x: 0.5, y: 0.8)
            }

            // Center text
            VStack(spacing: 1) {
                Text(hasData ? "\(Int(rate * 100))%" : "—")
                    .font(.system(size: size * 0.2, weight: .bold))
                Text(String(localized: "Discipline"))
                    .font(.system(size: size * 0.08))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 14-Day Bar Chart

    @ViewBuilder
    private var barChart: some View {
        let days = tracker.last14Days
        let maxVal = max(days.map { max($0.triggered, $0.completed) }.max() ?? 1, 1)

        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(days) { day in
                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 1) {
                            // Triggered bar
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 7, height: barHeight(day.triggered, max: maxVal))

                            // Completed bar (same earthy color as donuts)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(donutColor)
                                .frame(width: 7, height: barHeight(day.completed, max: maxVal))
                        }
                        .frame(height: 80, alignment: .bottom)

                        // Weekday label
                        Text(weekdayLabel(for: day.date))
                            .font(.system(size: 9))
                            .foregroundColor(isToday(day.date) ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(String(localized: "triggered"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(donutColor)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "completed"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Self-Report Bar Chart

    /// Colors for the three self-report categories
    private let succeededColor = Color(red: 0.45, green: 0.65, blue: 0.45)
    private let noticedColor = Color(red: 0.55, green: 0.55, blue: 0.70)
    private let forgotColor = Color(red: 0.70, green: 0.50, blue: 0.45)

    /// Self-report data for the last 14 days (archived + today)
    private var last14DaysSelfReports: [(date: String, succeeded: Int, noticed: Int, forgot: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Build lookup from archived reports
        var lookup: [String: DailySelfReport] = [:]
        for report in EventStore.shared.selfReports {
            lookup[report.date] = report
        }

        // Add today's live data
        let todayReport = SettingsManager.shared.currentSelfReportData()
        lookup[todayReport.date] = todayReport

        var result: [(date: String, succeeded: Int, noticed: Int, forgot: Int)] = []
        for offset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = formatter.string(from: date)
            if let report = lookup[key] {
                result.append((key, report.succeeded, report.noticed, report.forgot))
            } else {
                result.append((key, 0, 0, 0))
            }
        }
        return result
    }

    @ViewBuilder
    private var selfReportChart: some View {
        let days = last14DaysSelfReports
        let maxVal = max(days.map { max($0.succeeded, max($0.noticed, $0.forgot)) }.max() ?? 1, 1)

        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 1) {
                            // Succeeded bar
                            RoundedRectangle(cornerRadius: 1)
                                .fill(succeededColor)
                                .frame(width: 5, height: selfReportBarHeight(day.succeeded, max: maxVal))

                            // Noticed bar
                            RoundedRectangle(cornerRadius: 1)
                                .fill(noticedColor)
                                .frame(width: 5, height: selfReportBarHeight(day.noticed, max: maxVal))

                            // Forgot bar
                            RoundedRectangle(cornerRadius: 1)
                                .fill(forgotColor)
                                .frame(width: 5, height: selfReportBarHeight(day.forgot, max: maxVal))
                        }
                        .frame(height: 60, alignment: .bottom)

                        // Weekday label
                        Text(weekdayLabel(for: day.date))
                            .font(.system(size: 9))
                            .foregroundColor(isToday(day.date) ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Legend
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(succeededColor)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "succeeded"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(noticedColor)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "noticed"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(forgotColor)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "forgot"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    /// Bar height for self-report chart (minimum 2pt for non-zero)
    private func selfReportBarHeight(_ value: Int, max: Int) -> CGFloat {
        guard value > 0 else { return 0 }
        return Swift.max(CGFloat(value) / CGFloat(max) * 60, 2)
    }

    // MARK: - Slogans

    /// Philosophical slogan based on today's performance relative to lifetime
    private var currentSlogan: String {
        let lifetime = tracker.successRate
        let today = todayRate
        let hasToday = tracker.todayTriggered > 0
        let hasLifetime = tracker.lifetimeTriggered > 0

        // No data today
        guard hasToday else {
            return noDataSlogans.randomStable()
        }

        guard hasLifetime else {
            return steadySlogans.randomStable()
        }

        let diff = today - lifetime

        if diff > 0.15 {
            return deepKoanSlogans.randomStable()
        } else if diff > 0.10 {
            return thrivingSlogans.randomStable()
        } else if diff < -0.10 {
            return strugglingSlogans.randomStable()
        } else {
            return steadySlogans.randomStable()
        }
    }

    /// Today's success rate
    private var todayRate: Double {
        guard tracker.todayTriggered > 0 else { return 0 }
        return Double(tracker.todayCompleted) / Double(tracker.todayTriggered)
    }

    // Slogan collections — EN only in code, localized via Localizable.xcstrings
    private let deepKoanSlogans = [
        String(localized: "Now dissolve even the one who observes"),
        String(localized: "The gateless gate has been open all along"),
        String(localized: "Awareness without an observer — sit with that"),
    ]

    private let thrivingSlogans = [
        String(localized: "What was your face before your parents were born?"),
        String(localized: "The finger pointing at the moon is not the moon"),
        String(localized: "You have crossed the river. Why carry the raft?"),
        String(localized: "The eye cannot see itself — who is it that is aware?"),
        String(localized: "If you meet the Buddha on the road, keep walking"),
    ]

    private let steadySlogans = [
        String(localized: "The river flows as it always has"),
        String(localized: "Consistency is the quiet form of mastery"),
        String(localized: "Each breath a stone on the path"),
        String(localized: "The wheel turns. You are the axle."),
    ]

    private let strugglingSlogans = [
        String(localized: "Even Siddhartha had bad days under the tree"),
        String(localized: "The monkey mind wins today's round — tomorrow is yours"),
        String(localized: "Plato's cave has excellent Wi-Fi, but the exit is still there"),
        String(localized: "A scattered mind is just awareness with too many tabs open"),
        String(localized: "The candle doesn't apologize for flickering"),
    ]

    private let noDataSlogans = [
        String(localized: "In stillness rests the strength"),
        String(localized: "The journey of awareness has no finish line"),
        String(localized: "Before the first breath, everything is possible"),
    ]

    // MARK: - Helpers

    /// Calculate bar height proportional to max value (minimum 2pt for non-zero values)
    private func barHeight(_ value: Int, max: Int) -> CGFloat {
        guard value > 0 else { return 0 }
        return Swift.max(CGFloat(value) / CGFloat(max) * 80, 2)
    }

    /// Get abbreviated weekday letter for a "yyyy-MM-dd" date string
    private func weekdayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEEE"  // Single-letter weekday
        return dayFormatter.string(from: date)
    }

    /// Check if a "yyyy-MM-dd" string matches today
    private func isToday(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = formatter.string(from: Date())
        return dateString == todayString
    }
}

// MARK: - Stable Random Selection

/// Extension to pick a random element deterministically per day (so the slogan
/// doesn't change every time the view re-renders).
private extension Array where Element == String {
    func randomStable() -> String {
        guard !isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let seed = formatter.string(from: Date()).hashValue
        var rng = SeededRandomNumberGenerator(seed: UInt64(bitPattern: Int64(seed)))
        return self.randomElement(using: &rng) ?? self[0]
    }
}

/// Simple seeded RNG for deterministic per-day random selection
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
