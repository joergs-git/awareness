import SwiftUI

/// Progress statistics view showing a donut chart, today/lifetime counters,
/// and a 14-day bar chart of triggered vs completed blackouts.
struct ProgressView: View {

    @ObservedObject var tracker = ProgressTracker.shared

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Donut Chart
            donutChart
                .frame(width: 120, height: 120)
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

    // MARK: - Donut Chart

    @ViewBuilder
    private var donutChart: some View {
        let rate = tracker.successRate
        let hasData = tracker.lifetimeTriggered > 0

        ZStack {
            // Background ring (gray)
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)

            // Completed arc (green)
            if hasData && rate > 0 {
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Center text
            VStack(spacing: 2) {
                Text(hasData ? "\(Int(rate * 100))%" : "—")
                    .font(.system(size: 22, weight: .bold))
                Text(String(localized: "Success Rate"))
                    .font(.system(size: 9))
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
                            // Triggered bar (gray)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 6, height: barHeight(day.triggered, max: maxVal))

                            // Completed bar (green)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.green)
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
                        .fill(Color.green)
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
