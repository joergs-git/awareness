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
    @State private var showHealthKitPrompt = false

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 20, 30, 60, 120, 0]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Header
                Section {
                    VStack(spacing: 8) {
                        Text(String(localized: "Mindfulness in Action"))
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .primary.opacity(0.15), radius: 4, y: 2)
                        Text(String(localized: "In stillness rests the strength"))
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
                        Label(String(localized: "Status"), systemImage: "circle.fill")
                            .foregroundColor(statusColor)
                        Spacer()
                        Text(statusText)
                            .foregroundColor(.secondary)
                    }

                    if let nextDate = scheduler.nextNotificationDate, !settings.isSnoozed {
                        HStack {
                            Label(String(localized: "Next"), systemImage: "clock")
                            Spacer()
                            Text(formatTime(nextDate))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "Schedule"))
                }

                // MARK: - Progress
                Section {
                    NavigationLink {
                        ProgressView()
                    } label: {
                        HStack {
                            Label(String(localized: "Mindful Moments"), systemImage: "chart.pie")
                            Spacer()
                            Text("\(ProgressTracker.shared.todayCompleted)/\(ProgressTracker.shared.todayTriggered)")
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
                        Menu {
                            ForEach(ContentView.snoozeDurations, id: \.self) { minutes in
                                Button(snoozeLabel(for: minutes)) {
                                    snooze(for: minutes)
                                }
                            }
                        } label: {
                            Label(String(localized: "Snooze"), systemImage: "moon.fill")
                        }
                    }
                } header: {
                    Text(String(localized: "Snooze"))
                }

                // MARK: - Notification Warning
                if !notificationsAuthorized {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(String(localized: "Notifications are disabled. Awareness reminder needs notifications to remind you to pause."))
                                .font(.callout)
                        }
                        Button(String(localized: "Open Settings")) {
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
                        Label(String(localized: "Test Blackout"), systemImage: "play.circle")
                    }
                    Button {
                        scheduler.scheduleTestNotification()
                    } label: {
                        Label(String(localized: "Test Notification (3s)"), systemImage: "bell.badge")
                    }
                    if settings.healthKitEnabled && HealthKitManager.shared.isAuthorized() {
                        HStack {
                            Label(String(localized: "Mindful Minutes"), systemImage: "heart.fill")
                                .foregroundColor(.pink)
                            Spacer()
                            Text(String(localized: "Connected"))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "Actions"))
                }

                // MARK: - How It Works
                Section {
                    Label {
                        Text(String(localized: "At random intervals, you receive a gentle notification reminding you to pause"))
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text(String(localized: "Tap the notification to open a full-screen blackout with a gong sound"))
                    } icon: {
                        Image(systemName: "rectangle.inset.filled")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text(String(localized: "Close your eyes, feel your breath, notice your posture"))
                    } icon: {
                        Image(systemName: "wind")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text(String(localized: "After a few seconds the screen returns — you continue with a moment of clarity"))
                    } icon: {
                        Image(systemName: "sun.max")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)
                } header: {
                    Text(String(localized: "How It Works"))
                }

                // MARK: - Background
                Section {
                    Text(String(localized: "In the Vipassana tradition, awareness (sati) is the foundation of all practice. We spend hours staring at screens and gradually lose contact with ourselves — forgetting to breathe deeply, forgetting we even have a body.\n\nAwareness interrupts this pattern. A few times per hour, you are gently reminded to pause. These micro-interruptions become anchors of presence threaded through your day.\n\nThe goal of this app is to not need it anymore a little bit later."))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "Why This App?"))
                }

                // MARK: - About
                Section {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                    HStack {
                        Text(String(localized: "Version"))
                        Spacer()
                        Text(version)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(String(localized: "by"))
                        Spacer()
                        Text("joergsflow")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/joergs-git/awareness")!) {
                        HStack {
                            Text(String(localized: "GitHub"))
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Update Available
                    if UpdateChecker.shared.updateAvailable, let version = UpdateChecker.shared.latestVersion {
                        Link(destination: URL(string: UpdateChecker.shared.releaseURL)!) {
                            HStack {
                                Label(String(localized: "Update Available (v\(version))"), systemImage: "arrow.down.circle")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "About"))
                }
            }
            .navigationTitle(String(localized: "Awareness reminder"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                NotificationScheduler.shared.rescheduleAll()
            }) {
                SettingsView(settings: settings)
            }
            .fullScreenCover(isPresented: $showingBlackout) {
                BlackoutView(isPresented: $showingBlackout)
            }
            .task {
                // Small delay to let the permission dialog finish if it's showing
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkNotificationStatus()

                // Show HealthKit encouragement once if available and not yet enabled
                if HealthKitManager.shared.isAvailable && !settings.healthKitEnabled && !settings.healthKitPromptShown {
                    showHealthKitPrompt = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Re-check whenever app becomes active (e.g. returning from system Settings)
                Task { await checkNotificationStatus() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBlackout)) { _ in
                showingBlackout = true
            }
            .alert(String(localized: "Track Your Mindful Minutes?"), isPresented: $showHealthKitPrompt) {
                Button(String(localized: "Enable")) {
                    settings.healthKitEnabled = true
                    settings.healthKitPromptShown = true
                    Task { await HealthKitManager.shared.requestAuthorization() }
                }
                Button(String(localized: "Not Now"), role: .cancel) {
                    settings.healthKitPromptShown = true
                }
            } message: {
                Text(String(localized: "Awareness can log each mindful pause to Apple Health so you can track your practice over time."))
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
                return String(localized: "Snoozed until \(formatTime(until))")
            }
            return String(localized: "Snoozed indefinitely")
        }
        if !notificationsAuthorized { return String(localized: "Notifications disabled") }
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
        if minutes >= 60 { return "\(minutes / 60) " + (minutes >= 120 ? String(localized: "hours") : String(localized: "hour")) }
        return String(localized: "\(minutes) minutes")
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
