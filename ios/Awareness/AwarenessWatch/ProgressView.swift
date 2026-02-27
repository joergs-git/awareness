import SwiftUI

/// Compact progress statistics view for Apple Watch showing a donut chart,
/// today/lifetime counters, and success rate.
struct ProgressView: View {

    @ObservedObject var tracker = ProgressTracker.shared

    var body: some View {
        List {
            // MARK: - Donut Chart
            Section {
                HStack {
                    Spacer()
                    donutChart
                        .frame(width: 80, height: 80)
                    Spacer()
                }
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
        }
        .navigationTitle(String(localized: "Mindful Moments"))
    }

    // MARK: - Donut Chart

    @ViewBuilder
    private var donutChart: some View {
        let rate = tracker.successRate
        let hasData = tracker.lifetimeTriggered > 0

        ZStack {
            // Background ring (gray)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)

            // Completed arc (green)
            if hasData && rate > 0 {
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Center text
            Text(hasData ? "\(Int(rate * 100))%" : "—")
                .font(.system(size: 16, weight: .bold))
        }
    }
}
