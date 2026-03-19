import SwiftUI

/// Progress statistics view for iOS showing two donut charts (today + overall),
/// a philosophical slogan, today/lifetime counters, a 14-day bar chart,
/// and a candlestick awareness chart.
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

            // MARK: - 14-Day Awareness Candlestick Chart
            Section {
                awarenessChart
                    .padding(.vertical, 8)
            } header: {
                Text(String(localized: "Awareness"))
            }

            // MARK: - Duration Trend Chart
            if !tracker.recentSessionDurations.isEmpty {
                Section {
                    durationTrendChart
                        .padding(.vertical, 8)
                } header: {
                    Text(String(localized: "Duration Trend"))
                }
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

    // MARK: - Awareness Candlestick Chart

    @ViewBuilder
    private var awarenessChart: some View {
        let days = tracker.last14Days
        let hasData = days.contains { !$0.awarenessScores.isEmpty }
        let chartHeight: CGFloat = 60

        VStack(spacing: 4) {
            if hasData {
                ZStack(alignment: .bottom) {
                    // Candlestick wicks + median dots
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(days) { day in
                            VStack(spacing: 2) {
                                GeometryReader { geo in
                                    let width = geo.size.width
                                    let height = chartHeight

                                    if !day.awarenessScores.isEmpty {
                                        // Min-max wick (thin vertical line)
                                        let minY = height - CGFloat(day.awarenessMax) / 100.0 * height
                                        let maxY = height - CGFloat(day.awarenessMin) / 100.0 * height
                                        let wickHeight = max(maxY - minY, 1)

                                        Rectangle()
                                            .fill(Color.gray.opacity(0.4))
                                            .frame(width: 1, height: wickHeight)
                                            .position(x: width / 2, y: minY + wickHeight / 2)

                                        // Median dot
                                        let medianY = height - CGFloat(day.awarenessMedian) / 100.0 * height
                                        Circle()
                                            .fill(donutColor)
                                            .frame(width: 6, height: 6)
                                            .position(x: width / 2, y: medianY)
                                    }
                                }
                                .frame(height: chartHeight)

                                // Weekday label
                                Text(weekdayLabel(for: day.date))
                                    .font(.system(size: 9))
                                    .foregroundColor(isToday(day.date) ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Trend line connecting median dots
                    CandlestickTrendLine(days: days, chartHeight: chartHeight, color: donutColor)
                        .frame(height: chartHeight)
                        .allowsHitTesting(false)
                }
            }

            // Legend
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 1, height: 10)
                    Text(String(localized: "Focus Duration"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(donutColor)
                        .frame(width: 5, height: 5)
                    Text(String(localized: "Median"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Duration Trend Chart

    @ViewBuilder
    private var durationTrendChart: some View {
        let sessions = tracker.recentSessionDurations
        let chartHeight: CGFloat = 60

        VStack(spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let count = sessions.count
                    let maxDuration = sessions.max() ?? 1
                    let yScale = maxDuration > 0 ? chartHeight / maxDuration : 1

                    // Individual session dots
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, duration in
                        let x = count > 1
                            ? width * CGFloat(index) / CGFloat(count - 1)
                            : width / 2
                        let y = chartHeight - duration * yScale

                        Circle()
                            .fill(donutColor.opacity(0.35))
                            .frame(width: 5, height: 5)
                            .position(x: x, y: y)
                    }

                    // Rolling 20-session moving average line
                    DurationTrendLine(
                        sessions: sessions,
                        chartHeight: chartHeight,
                        color: donutColor,
                        maxDuration: maxDuration,
                        windowSize: 20
                    )
                }
                .frame(height: chartHeight)
            }

            // Legend
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(donutColor.opacity(0.35))
                        .frame(width: 5, height: 5)
                    Text(String(localized: "session"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(donutColor)
                        .frame(width: 12, height: 1.5)
                    Text(String(localized: "20-session avg"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
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

// MARK: - Duration Trend Line

/// Draws a rolling moving average line over session duration data points.
struct DurationTrendLine: View {
    let sessions: [Double]
    let chartHeight: CGFloat
    let color: Color
    let maxDuration: Double
    let windowSize: Int

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = sessions.count
            let yScale = maxDuration > 0 ? chartHeight / maxDuration : 1

            Path { path in
                guard count >= 2 else { return }
                var started = false

                for i in 0..<count {
                    let windowStart = max(0, i - windowSize + 1)
                    let window = Array(sessions[windowStart...i])
                    let avg = window.reduce(0, +) / Double(window.count)

                    let x = width * CGFloat(i) / CGFloat(count - 1)
                    let y = chartHeight - avg * yScale

                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

// MARK: - Candlestick Trend Line

/// Draws a connecting line between median dots across days in the awareness chart.
/// Skips days without data, connecting only adjacent days that have scores.
struct CandlestickTrendLine: View {
    let days: [DayRecord]
    let chartHeight: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let dayCount = CGFloat(days.count)
            let dayWidth = totalWidth / dayCount

            Path { path in
                var started = false
                for (index, day) in days.enumerated() {
                    guard !day.awarenessScores.isEmpty else { continue }
                    let x = dayWidth * CGFloat(index) + dayWidth / 2
                    let y = chartHeight - CGFloat(day.awarenessMedian) / 100.0 * chartHeight

                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1)
        }
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
