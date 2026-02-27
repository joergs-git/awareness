import SwiftUI

/// Home screen for the watchOS Awareness app.
/// Shows status, next blackout time, test button, snooze controls, and settings link.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared

    @State private var showingBlackout = false

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
                        Label(String(localized: "Test Blackout"), systemImage: "play.circle")
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
            .onReceive(NotificationCenter.default.publisher(for: .showBlackout)) { _ in
                showingBlackout = true
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
}
