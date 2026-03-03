import SwiftUI

/// Home screen for the iOS Awareness app.
/// Shows status, practice card, micro-task, snooze controls, and settings access.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared
    @ObservedObject var foregroundScheduler = ForegroundScheduler.shared

    @State private var showingBlackout = false
    @State private var showingSettings = false
    @State private var notificationStatus: String = "Checking..."
    @State private var notificationsAuthorized = true
    @State private var showHealthKitPrompt = false

    // Practice card & micro-task state
    @State private var todaysCard: PracticeCard?
    @State private var currentTask: MicroTask?
    @State private var selfReport: DailySelfReport?
    @State private var showingCardDetail = false
    @State private var showingTaskDetail = false

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

                // MARK: - Practice Card Banner + Micro-Task
                if let card = todaysCard {
                    Section {
                        VStack(spacing: 0) {
                            // Card banner (tap for detail)
                            Button {
                                showingCardDetail = true
                            } label: {
                                practiceCardBanner(card: card)
                            }
                            .buttonStyle(.plain)

                            // Micro-task connected below the card with thin colored bridge
                            if let task = currentTask {
                                // Thin color connector between card and task
                                Rectangle()
                                    .fill(card.color.opacity(0.4))
                                    .frame(width: 2, height: 8)

                                // Task box with matching border (extra top padding so caption
                                // isn't clipped under the card's rounded bottom edge)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "Inspirational idea for you to explore"))
                                        .font(.caption.smallCaps())
                                        .foregroundColor(.secondary)
                                    Text(task.localizedText)
                                        .font(.callout.italic())
                                        .foregroundColor(.primary.opacity(0.8))
                                        .lineLimit(3)
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(card.color.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal, 16)
                                .onTapGesture { showingTaskDetail = true }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }

                // MARK: - Breathe Now (prominent, no scrolling needed)
                Section {
                    Button {
                        showingBlackout = true
                    } label: {
                        Text(String(localized: "Breathe now"))
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
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

                    if let nextDate = nextScheduledDate, !settings.isSnoozed {
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
                            WidgetDataBridge.shared.updateWidget()
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

                // MARK: - Notification Info
                if !notificationsAuthorized {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(String(localized: "Enable notifications for background reminders. Without them, awareness pauses only work while the app is open."))
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
                    if notificationsAuthorized {
                        Button {
                            scheduler.scheduleTestNotification()
                        } label: {
                            Label(String(localized: "Test Notification (3s)"), systemImage: "bell.badge")
                        }
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
                        Text(String(localized: "At random intervals, you receive a gentle reminder to pause"))
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundColor(.accentColor)
                    }
                    .font(.callout)

                    Label {
                        Text(String(localized: "A full-screen blackout appears with a gong sound"))
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
            .sheet(isPresented: $showingCardDetail) {
                if let card = todaysCard {
                    PracticeCardDetailView(card: card)
                }
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = currentTask, let card = todaysCard {
                    MicroTaskDetailView(task: task, card: card)
                }
            }
            .fullScreenCover(isPresented: $showingBlackout, onDismiss: {
                handlePostBlackout()
            }) {
                BlackoutView(isPresented: $showingBlackout)
            }
            .task {
                // Small delay to let the permission dialog finish if it's showing
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkNotificationStatus()

                // Load today's practice card and micro-task
                todaysCard = settings.todaysPracticeCard()
                currentTask = settings.currentMicroTask()
                selfReport = settings.currentSelfReportData()

                // Show HealthKit encouragement once if available and not yet enabled
                if HealthKitManager.shared.isAvailable && !settings.healthKitEnabled && !settings.healthKitPromptShown {
                    showHealthKitPrompt = true
                }

                // Update home screen widget with initial state
                WidgetDataBridge.shared.updateWidget()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Re-check whenever app becomes active (e.g. returning from system Settings)
                Task { await checkNotificationStatus() }
                // Refresh card/task state on foreground return
                todaysCard = settings.todaysPracticeCard()
                currentTask = settings.currentMicroTask()
                selfReport = settings.currentSelfReportData()
                // Keep widget up to date
                WidgetDataBridge.shared.updateWidget()
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

    // MARK: - Practice Card Banner

    @ViewBuilder
    private func practiceCardBanner(card: PracticeCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Spacer()

                // Self-report counters
                if let report = selfReport {
                    selfReportCounters(report: report)
                }
            }

        }
        .padding(12)
        .background(
            CardBackground(color: card.color)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Self-Report Counters

    @ViewBuilder
    private func selfReportCounters(report: DailySelfReport) -> some View {
        HStack(spacing: 12) {
            // Succeeded (checkmark)
            Button {
                incrementSelfReport(\.succeeded)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                        .font(.body)
                    Text("\(report.succeeded)")
                        .font(.footnote.monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.85))
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            // Noticed (eye)
            Button {
                incrementSelfReport(\.noticed)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "eye.circle")
                        .font(.body)
                    Text("\(report.noticed)")
                        .font(.footnote.monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.85))
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            // Forgot (circle)
            Button {
                incrementSelfReport(\.forgot)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "circle")
                        .font(.body)
                    Text("\(report.forgot)")
                        .font(.footnote.monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.85))
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if settings.isSnoozed { return .orange }
        return .green
    }

    private var statusText: String {
        if settings.isSnoozed {
            if let until = settings.snoozeUntil, until < Date.distantFuture {
                return String(localized: "Snoozed until \(formatTime(until))")
            }
            return String(localized: "Snoozed indefinitely")
        }
        if !notificationsAuthorized {
            return String(localized: "Active (foreground only)")
        }
        return String(localized: "Active")
    }

    /// The earliest scheduled date from either the foreground timer or pending notifications
    private var nextScheduledDate: Date? {
        let dates = [scheduler.nextNotificationDate, foregroundScheduler.nextBlackoutDate].compactMap { $0 }
        return dates.min()
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
        // Update widget to reflect snoozed state
        WidgetDataBridge.shared.updateWidget()
    }

    private func checkNotificationStatus() async {
        let status = await scheduler.checkAuthorizationStatus()
        notificationsAuthorized = (status == .authorized || status == .provisional)
    }

    /// Increment a self-report counter by keypath
    private func incrementSelfReport(_ keyPath: WritableKeyPath<DailySelfReport, Int>) {
        var report = settings.currentSelfReportData()
        report[keyPath: keyPath] += 1
        settings.updateSelfReport(report)
        selfReport = report
    }

    /// Handle post-blackout logic: refresh card/task/report state and update widget
    private func handlePostBlackout() {
        // Refresh card, micro-task, and self-report state
        todaysCard = settings.todaysPracticeCard()
        currentTask = settings.currentMicroTask()
        selfReport = settings.currentSelfReportData()
        // Update home screen widget with latest progress
        WidgetDataBridge.shared.updateWidget()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout in the foreground
    static let showBlackout = Notification.Name("showBlackout")
}

// MARK: - Card Background (aquarelle style)

/// Organic watercolor-style background for practice card banners.
/// Layers blurred shapes with hue variations of the card's color.
struct CardBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            color

            Ellipse()
                .fill(color.opacity(0.6))
                .frame(width: 200, height: 100)
                .offset(x: -60, y: -20)
                .blur(radius: 30)

            Circle()
                .fill(Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.2))
                .frame(width: 120, height: 120)
                .offset(x: 80, y: 10)
                .blur(radius: 25)

            Ellipse()
                .fill(color.opacity(0.8))
                .frame(width: 180, height: 80)
                .offset(x: 20, y: 30)
                .blur(radius: 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Aquarelle Background

/// Soft watercolor-style background using layered blurred shapes.
/// Creates an organic, contemplative feel with warm Chinese sunrise tones.
struct AquarelleBackground: View {
    var body: some View {
        ZStack {
            Color.black

            // Warm sunrise watercolor blobs — amber, peach, dusty rose, warm gold
            Ellipse()
                .fill(Color(red: 0.76, green: 0.52, blue: 0.32).opacity(0.4))
                .frame(width: 300, height: 200)
                .offset(x: -50, y: -100)
                .blur(radius: 70)

            Circle()
                .fill(Color(red: 0.85, green: 0.62, blue: 0.45).opacity(0.3))
                .frame(width: 250, height: 250)
                .offset(x: 80, y: 50)
                .blur(radius: 80)

            Ellipse()
                .fill(Color(red: 0.72, green: 0.48, blue: 0.52).opacity(0.25))
                .frame(width: 200, height: 300)
                .offset(x: -30, y: 120)
                .blur(radius: 65)

            Circle()
                .fill(Color(red: 0.82, green: 0.68, blue: 0.42).opacity(0.2))
                .frame(width: 180, height: 180)
                .offset(x: 60, y: -150)
                .blur(radius: 60)
        }
    }
}

// MARK: - Practice Card Detail View

/// Full-screen card view showing the practice card's theme, description, and color.
struct PracticeCardDetailView: View {
    let card: PracticeCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            card.color.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(card.localizedTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(card.localizedDescription)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Close"))
                        .font(.headline)
                        .foregroundColor(card.color)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Micro-Task Detail View

/// Full-screen task view with aquarelle background and card connection.
struct MicroTaskDetailView: View {
    let task: MicroTask
    let card: PracticeCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AquarelleBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(String(localized: "Inspirational idea for you to explore"))
                    .font(.subheadline.smallCaps())
                    .foregroundColor(.white.opacity(0.6))

                Text(task.localizedText)
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Card connection badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(card.color)
                        .frame(width: 8, height: 8)
                    Text(card.localizedTitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Close"))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}
