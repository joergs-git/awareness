import SwiftUI

/// Home screen for the iOS Awareness app.
/// Shows status, snooze controls, test blackout, and settings access.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared

    @State private var showingBlackout = false
    @State private var showingSettings = false
    @State private var notificationStatus: String = "Checking..."
    @State private var notificationsAuthorized = true

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 20, 30, 60, 120, 0]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Status Section
                Section {
                    HStack {
                        Label("Status", systemImage: "circle.fill")
                            .foregroundColor(statusColor)
                        Spacer()
                        Text(statusText)
                            .foregroundColor(.secondary)
                    }

                    if let nextDate = scheduler.nextNotificationDate, !settings.isSnoozed {
                        HStack {
                            Label("Next", systemImage: "clock")
                            Spacer()
                            Text(formatTime(nextDate))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Schedule")
                }

                // MARK: - Notification Warning
                if !notificationsAuthorized {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notifications are disabled. Awareness needs notifications to remind you to pause.")
                                .font(.callout)
                        }
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                // MARK: - Actions
                Section {
                    Button {
                        showingBlackout = true
                    } label: {
                        Label("Test Blackout", systemImage: "play.circle")
                    }
                } header: {
                    Text("Actions")
                }

                // MARK: - Snooze
                Section {
                    if settings.isSnoozed {
                        Button {
                            scheduler.handleResume()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        Menu {
                            ForEach(ContentView.snoozeDurations, id: \.self) { minutes in
                                Button(snoozeLabel(for: minutes)) {
                                    snooze(for: minutes)
                                }
                            }
                        } label: {
                            Label("Snooze", systemImage: "moon.fill")
                        }
                    }
                } header: {
                    Text("Snooze")
                }

                // MARK: - About
                Section {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version)
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/joergs-git/awareness")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Update Available
                    if UpdateChecker.shared.updateAvailable, let version = UpdateChecker.shared.latestVersion {
                        Link(destination: URL(string: UpdateChecker.shared.releaseURL)!) {
                            HStack {
                                Label("Update Available (v\(version))", systemImage: "arrow.down.circle")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("A mindfulness timer for your iPhone.\nRandomly reminds you to pause and breathe.")
                }
            }
            .navigationTitle("Awareness")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings)
            }
            .fullScreenCover(isPresented: $showingBlackout) {
                BlackoutView(isPresented: $showingBlackout)
            }
            .task {
                await checkNotificationStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBlackout)) { _ in
                showingBlackout = true
            }
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if settings.isSnoozed { return .orange }
        if !notificationsAuthorized { return .red }
        return .green
    }

    private var statusText: String {
        if settings.isSnoozed {
            if let until = settings.snoozeUntil, until < Date.distantFuture {
                return "Snoozed until \(formatTime(until))"
            }
            return "Snoozed indefinitely"
        }
        if !notificationsAuthorized { return "Notifications disabled" }
        return "Active"
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func snoozeLabel(for minutes: Int) -> String {
        if minutes == 0 { return "Until I resume" }
        if minutes >= 60 { return "\(minutes / 60) hour\(minutes >= 120 ? "s" : "")" }
        return "\(minutes) minutes"
    }

    private func snooze(for minutes: Int) {
        if minutes == 0 {
            scheduler.handleSnooze(until: Date.distantFuture)
        } else {
            scheduler.handleSnooze(until: Date().addingTimeInterval(Double(minutes) * 60))
        }
    }

    private func checkNotificationStatus() async {
        let status = await scheduler.checkAuthorizationStatus()
        notificationsAuthorized = (status == .authorized || status == .provisional)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout in the foreground
    static let showBlackout = Notification.Name("showBlackout")
}
