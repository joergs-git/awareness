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
                // MARK: - Header
                Section {
                    VStack(spacing: 6) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .primary.opacity(0.15), radius: 4, y: 2)
                        Text("Awareness")
                            .font(.title2.weight(.medium))
                        Text("A mindfulness timer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

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

                // MARK: - How It Works
                Section {
                    Label {
                        Text("At random intervals, you receive a gentle notification reminding you to pause")
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text("Tap the notification to open a full-screen blackout with a gong sound")
                    } icon: {
                        Image(systemName: "rectangle.inset.filled")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text("Close your eyes, feel your breath, notice your posture")
                    } icon: {
                        Image(systemName: "wind")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text("After a few seconds the screen returns — you continue with a moment of clarity")
                    } icon: {
                        Image(systemName: "sun.max")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)
                } header: {
                    Text("How It Works")
                }

                // MARK: - Background
                Section {
                    Text("In the Vipassana tradition, awareness (sati) is the foundation of all practice. We spend hours staring at screens and gradually lose contact with ourselves — forgetting to breathe deeply, forgetting we even have a body.\n\nAwareness interrupts this pattern. A few times per hour, you are gently reminded to pause. These micro-interruptions become anchors of presence threaded through your day.\n\nThe goal of this app is to not need it anymore a little bit later.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("Why This App?")
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

                    HStack {
                        Text("by")
                        Spacer()
                        Text("joergsflow")
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
                // Small delay to let the permission dialog finish if it's showing
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkNotificationStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Re-check whenever app becomes active (e.g. returning from system Settings)
                Task { await checkNotificationStatus() }
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
