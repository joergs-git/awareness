import SwiftUI

/// Compact progress statistics view for Apple Watch showing two donut charts
/// (today + overall), a philosophical slogan, today/lifetime counters,
/// and a compact awareness sparkline.
struct ProgressView: View {

    @ObservedObject var tracker = ProgressTracker.shared

    /// Warm earthy color for donut arcs (Chinese sunrise palette)
    private let donutColor = Color(red: 0.72, green: 0.50, blue: 0.38)

    var body: some View {
        List {
            // MARK: - Twin Donut Charts
            Section {
                HStack(spacing: 12) {
                    Spacer()

                    // Today donut
                    VStack(spacing: 2) {
                        brushDonut(
                            rate: todayRate,
                            hasData: tracker.todayTriggered > 0,
                            size: 60,
                            lineWidth: 8
                        )
                        .frame(width: 60, height: 60)

                        Text(String(localized: "Today"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    // Overall donut
                    VStack(spacing: 2) {
                        brushDonut(
                            rate: tracker.successRate,
                            hasData: tracker.lifetimeTriggered > 0,
                            size: 60,
                            lineWidth: 8
                        )
                        .frame(width: 60, height: 60)

                        Text(String(localized: "Overall"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // MARK: - Slogan
            Section {
                Text(currentSlogan)
                    .font(.system(size: 11).italic())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            // MARK: - Stats
            Section {
                HStack {
                    Text(String(localized: "Today"))
                        .font(.footnote)
                    Spacer()
                    Text("\(tracker.todayCompleted) / \(tracker.todayTriggered)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(String(localized: "Lifetime"))
                        .font(.footnote)
                    Spacer()
                    Text("\(tracker.lifetimeCompleted) / \(tracker.lifetimeTriggered)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(String(localized: "Discipline"))
                        .font(.footnote)
                    Spacer()
                    Text(tracker.lifetimeTriggered > 0 ? "\(Int(tracker.successRate * 100))%" : "—")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - Awareness (Median + 7-Day Sparkline)
            Section {
                VStack(spacing: 6) {
                    // Today's median awareness
                    HStack {
                        if let median = tracker.todayMedianAwareness {
                            Text("Ø \(Int(median))%")
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                                .foregroundColor(donutColor)
                        } else {
                            Text("Ø —")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // 7-day sparkline of median awareness
                    let last7 = Array(tracker.last14Days.suffix(7))
                    if last7.contains(where: { !$0.awarenessScores.isEmpty }) {
                        AwarenessSparkline(days: last7, color: donutColor)
                            .frame(height: 24)
                    }
                }
                .listRowBackground(Color.clear)
            } header: {
                Text(String(localized: "Awareness"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle(String(localized: "Mindful Moments"))
    }

    // MARK: - Brush-Style Donut

    @ViewBuilder
    private func brushDonut(rate: Double, hasData: Bool, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: lineWidth)

            if hasData && rate > 0 {
                // Primary arc
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Brush overlays for ink texture
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth * 0.85, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .offset(x: 0.8, y: -0.6)

                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .offset(x: -0.6, y: 0.9)

                // Third overlay with dashed stroke for subtle texture breaks
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(donutColor.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round, dash: [8, 2]))
                    .rotationEffect(.degrees(-90))
                    .offset(x: 0.4, y: 0.5)
            }

            // Center text
            Text(hasData ? "\(Int(rate * 100))%" : "—")
                .font(.system(size: size * 0.22, weight: .bold))
        }
    }

    // MARK: - Slogans

    private var currentSlogan: String {
        let lifetime = tracker.successRate
        let today = todayRate
        let hasToday = tracker.todayTriggered > 0
        let hasLifetime = tracker.lifetimeTriggered > 0

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

    private var todayRate: Double {
        guard tracker.todayTriggered > 0 else { return 0 }
        return Double(tracker.todayCompleted) / Double(tracker.todayTriggered)
    }

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
}

// MARK: - 7-Day Awareness Sparkline

/// Compact sparkline showing median awareness for the last 7 days.
/// Dots for days with data, connected by a line.
struct AwarenessSparkline: View {
    let days: [DayRecord]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let dayWidth = width / CGFloat(max(days.count, 1))

            // Trend line
            Path { path in
                var started = false
                for (index, day) in days.enumerated() {
                    guard !day.awarenessScores.isEmpty else { continue }
                    let x = dayWidth * CGFloat(index) + dayWidth / 2
                    let y = height - CGFloat(day.awarenessMedian) / 100.0 * height

                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1)

            // Dots
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if !day.awarenessScores.isEmpty {
                    let x = dayWidth * CGFloat(index) + dayWidth / 2
                    let y = height - CGFloat(day.awarenessMedian) / 100.0 * height
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Stable Random Selection

private extension Array where Element == String {
    func randomStable() -> String {
        guard !isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let seed = formatter.string(from: Date()).hashValue
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(seed)))
        return self.randomElement(using: &rng) ?? self[0]
    }
}

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
