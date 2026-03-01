import SwiftUI

/// Home screen for the watchOS Awareness app.
/// Shows status, next blackout time, test button, snooze controls, and settings link.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared

    @State private var showingBlackout = false
    /// Whether to show the namaste overlay after an alarm-dismissed blackout
    @State private var showingNamaste = false
    /// Opacity for the namaste overlay fade in/out
    @State private var namasteOpacity: Double = 0

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 30, 60, 0]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Status
                Section {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .font(.footnote)
                    }

                    if let nextDate = scheduler.nextNotificationDate, !settings.isSnoozed {
                        HStack {
                            Image(systemName: "clock")
                                .font(.footnote)
                            Text(String(localized: "Next: \(formatTime(nextDate))"))
                                .font(.footnote)
                        }
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
                            Text("\(ProgressTracker.shared.todayCompleted)/\(ProgressTracker.shared.todayTriggered)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
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

    // MARK: - Computed

    private var statusColor: Color {
        settings.isSnoozed ? .orange : .green
    }

    private var statusText: String {
        if settings.isSnoozed {
            if let until = settings.snoozeUntil, until < Date.distantFuture {
                return String(localized: "Snoozed until \(formatTime(until))")
            }
            return String(localized: "Snoozed")
        }
        return String(localized: "Active")
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
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout
    static let showBlackout = Notification.Name("showBlackout")
    /// Posted when the end-of-blackout notification fires, triggering dismiss
    static let dismissBlackout = Notification.Name("dismissBlackout")
}
