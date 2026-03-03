import SwiftUI

/// Progress statistics view showing twin donut charts (today + all-time),
/// today/lifetime counters, and a 14-day bar chart of triggered vs completed blackouts.
struct ProgressView: View {

    @ObservedObject var tracker = ProgressTracker.shared

    /// Warm earthy color for donut arcs (Chinese sunrise palette)
    private let donutColor = Color(red: 0.72, green: 0.50, blue: 0.38)

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Twin Donut Charts
            HStack(spacing: 24) {
                // Today donut
                VStack(spacing: 4) {
                    brushDonut(
                        rate: todayRate,
                        hasData: tracker.todayTriggered > 0,
                        size: 100,
                        lineWidth: 14
                    )
                    .frame(width: 100, height: 100)

                    Text(String(localized: "Today"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // All-time donut
                VStack(spacing: 4) {
                    brushDonut(
                        rate: tracker.successRate,
                        hasData: tracker.lifetimeTriggered > 0,
                        size: 100,
                        lineWidth: 14
                    )
                    .frame(width: 100, height: 100)

                    Text(String(localized: "Overall"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)

            // MARK: - Stats
            VStack(spacing: 6) {
                HStack {
                    Text(String(localized: "Today"))
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(tracker.todayCompleted) \(String(localized: "completed")), \(tracker.todayTriggered) \(String(localized: "triggered"))")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(String(localized: "Lifetime"))
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(tracker.lifetimeCompleted) \(String(localized: "completed")), \(tracker.lifetimeTriggered) \(String(localized: "triggered"))")
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // MARK: - 14-Day Bar Chart
            barChart
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(width: 300)
    }

    // MARK: - Brush-Style Donut

    /// A donut chart with a brush-stroke effect: multiple overlapping arcs at slight offsets
    /// create the impression of ink brush irregularity (matching iOS Chinese sunrise style).
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

    /// Today's success rate (0.0 to 1.0)
    private var todayRate: Double {
        guard tracker.todayTriggered > 0 else { return 0 }
        return Double(tracker.todayCompleted) / Double(tracker.todayTriggered)
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
                            // Triggered bar (gray)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 6, height: barHeight(day.triggered, max: maxVal))

                            // Completed bar (earthy color matching donuts)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(donutColor)
                                .frame(width: 6, height: barHeight(day.completed, max: maxVal))
                        }
                        .frame(height: 60, alignment: .bottom)

                        // Weekday label
                        Text(weekdayLabel(for: day.date))
                            .font(.system(size: 8))
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
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(donutColor)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "completed"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    /// Calculate bar height proportional to max value (minimum 2pt for non-zero values)
    private func barHeight(_ value: Int, max maxVal: Int) -> CGFloat {
        guard value > 0 else { return 0 }
        return Swift.max(CGFloat(value) / CGFloat(maxVal) * 60, 2)
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
