import SwiftUI

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
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
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

                            // Three counter buttons in a row
                            if let report = selfReport {
                                HStack(spacing: 12) {
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
                        .padding(.vertical, 4)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(card.color)
                        )
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

                // MARK: - Actions
                Section {
                    Button {
                        showingBlackout = true
                    } label: {
                        Label(String(localized: "Breathe now"), systemImage: "play.circle")
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

                // MARK: - Alarm Debug (temporary diagnostic)
                if !AlarmSessionManager.debugLog().isEmpty {
                    Section("Alarm Debug") {
                        ForEach(AlarmSessionManager.debugLog(), id: \.self) { entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
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
                    .font(.system(size: 14))
                Text("\(count)")
                    .font(.system(size: 10).monospacedDigit())
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

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout
    static let showBlackout = Notification.Name("showBlackout")
    /// Posted when the end-of-blackout notification fires, triggering dismiss
    static let dismissBlackout = Notification.Name("dismissBlackout")
}
