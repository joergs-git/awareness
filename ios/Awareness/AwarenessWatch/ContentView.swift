import SwiftUI
import WidgetKit

/// Home screen for the watchOS Awareness app.
/// Compact layout: status dot + next time at top, practice card, self-report,
/// progress link, snooze, actions, settings.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared

    @State private var showingBlackout = false
    /// Whether to show the namaste overlay after an alarm-dismissed blackout
    @State private var showingNamaste = false
    /// Opacity for the namaste overlay fade in/out
    @State private var namasteOpacity: Double = 0

    /// Today's practice card (assigned from iOS or locally)
    @State private var todaysCard: PracticeCard?
    /// Self-report counters for today
    @State private var selfReport: DailySelfReport?

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 30, 60, 0]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Compact Status Bar (dot + next time)
                Section {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        if settings.isSnoozed {
                            if let until = settings.snoozeUntil, until < Date.distantFuture {
                                Text(formatTime(until))
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            } else {
                                Text(String(localized: "Paused"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                        } else if let nextDate = scheduler.nextNotificationDate {
                            Text(formatTime(nextDate))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Today's progress counter
                        Text("\(ProgressTracker.shared.todayCompleted)/\(ProgressTracker.shared.todayTriggered)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }

                // MARK: - Self-Report Counters
                if let card = todaysCard {
                    Section {
                        VStack(spacing: 6) {
                            // Short card title (compact for watch)
                            Text(card.localizedShortTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            // Three counter buttons in a row (wider spacing for easier tapping)
                            if let report = selfReport {
                                HStack(spacing: 20) {
                                    selfReportButton(
                                        icon: "checkmark.circle",
                                        count: report.succeeded,
                                        action: { incrementSelfReport(\.succeeded) }
                                    )
                                    selfReportButton(
                                        icon: "eye.circle",
                                        count: report.noticed,
                                        action: { incrementSelfReport(\.noticed) }
                                    )
                                    selfReportButton(
                                        icon: "circle",
                                        count: report.forgot,
                                        action: { incrementSelfReport(\.forgot) }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .listRowBackground(
                            WatchCardBackground(color: card.color)
                        )
                    }
                }

                // MARK: - Breathe Now
                Section {
                    Button {
                        showingBlackout = true
                    } label: {
                        Label(String(localized: "Breathe now"), systemImage: "play.circle")
                    }
                }

                // MARK: - Progress
                Section {
                    NavigationLink {
                        ProgressView()
                    } label: {
                        HStack {
                            Label(String(localized: "Mindful Moments"), systemImage: "chart.pie")
                                .font(.footnote)
                            Spacer()
                        }
                    }
                }

                // MARK: - Snooze
                Section {
                    if settings.isSnoozed {
                        Button {
                            scheduler.handleResume()
                        } label: {
                            Label(String(localized: "Resume"), systemImage: "play.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        ForEach(ContentView.snoozeDurations, id: \.self) { minutes in
                            Button {
                                snooze(for: minutes)
                            } label: {
                                Label(snoozeLabel(for: minutes), systemImage: "moon.fill")
                                    .font(.footnote)
                            }
                        }
                    }
                }

                // MARK: - Settings
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(String(localized: "Settings"), systemImage: "gear")
                    }
                }

            }
            .navigationTitle(String(localized: "Awareness reminder"))
            .fullScreenCover(isPresented: $showingBlackout) {
                BlackoutView(isPresented: $showingBlackout)
            }
            .task {
                todaysCard = settings.todaysPracticeCard()
                selfReport = settings.currentSelfReportData()
                // Ensure complication shows the same card as the app
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBlackout)) { _ in
                showingBlackout = true
            }
            .onChange(of: showingBlackout) { _, isShowing in
                // When the blackout dismisses after an alarm fired, show namaste here
                // because the system alarm UI covered the BlackoutView's namaste
                if !isShowing && AlarmSessionManager.shared.hasFired {
                    AlarmSessionManager.shared.resetHasFired()
                    showingNamaste = true
                    withAnimation(.easeIn(duration: 0.3)) {
                        namasteOpacity = 1.0
                    }
                    // Hold for 1.5s then fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            namasteOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingNamaste = false
                        }
                    }
                }

                // Refresh self-report after blackout
                if !isShowing {
                    selfReport = settings.currentSelfReportData()
                    todaysCard = settings.todaysPracticeCard()
                    // Refresh complication after blackout (card may have changed)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .overlay {
                // Namaste overlay shown after alarm-dismissed blackout
                if showingNamaste {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Text("🙏")
                            .font(.system(size: 48))
                    }
                    .opacity(namasteOpacity)
                }
            }
        }
    }

    // MARK: - Self-Report Button

    @ViewBuilder
    private func selfReportButton(icon: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text("\(count)")
                    .font(.system(size: 12).monospacedDigit())
            }
            .foregroundColor(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var statusColor: Color {
        settings.isSnoozed ? .orange : .green
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func snoozeLabel(for minutes: Int) -> String {
        if minutes == 0 { return String(localized: "Until I resume") }
        if minutes >= 60 { return "\(minutes / 60)h" }
        return "\(minutes) min"
    }

    private func snooze(for minutes: Int) {
        if minutes == 0 {
            scheduler.handleSnooze(until: Date.distantFuture)
        } else {
            scheduler.handleSnooze(until: Date().addingTimeInterval(Double(minutes) * 60))
        }
    }

    /// Increment a self-report counter by keypath
    private func incrementSelfReport(_ keyPath: WritableKeyPath<DailySelfReport, Int>) {
        var report = settings.currentSelfReportData()
        report[keyPath: keyPath] += 1
        settings.updateSelfReport(report)
        selfReport = report
        // Light haptic on watch
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}

// MARK: - Watch Card Background (aquarelle style)

/// Compact watercolor-style background for the practice card section on watchOS.
struct WatchCardBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            color

            Ellipse()
                .fill(color.opacity(0.6))
                .frame(width: 120, height: 60)
                .offset(x: -30, y: -10)
                .blur(radius: 18)

            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 70, height: 70)
                .offset(x: 50, y: 5)
                .blur(radius: 15)

            Ellipse()
                .fill(color.opacity(0.8))
                .frame(width: 100, height: 50)
                .offset(x: 10, y: 15)
                .blur(radius: 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout
    static let showBlackout = Notification.Name("showBlackout")
    /// Posted when the end-of-blackout notification fires, triggering dismiss
    static let dismissBlackout = Notification.Name("dismissBlackout")
}
