import SwiftUI
import WidgetKit

/// Home screen for the watchOS Awareness app.
/// Compact layout: status dot + next time at top, practice card, self-report,
/// progress link, snooze, actions, settings.
struct ContentView: View {

    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var scheduler = NotificationScheduler.shared

    @State private var showingBlackout = false
    /// Whether to show the awareness check overlay after an alarm-dismissed blackout
    @State private var showingAwarenessCheck = false
    /// Opacity for the awareness check overlay fade in/out
    @State private var awarenessCheckOpacity: Double = 0
    /// Awareness slider value for the overlay (0–100, default at center)
    @State private var overlaySliderValue: Double = 50

    /// Today's practice card (assigned from iOS or locally)
    @State private var todaysCard: PracticeCard?
    /// Current micro-task for today
    @State private var currentTask: MicroTask?
    /// Whether to show the practice card detail sheet
    @State private var showingCardDetail = false

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 30, 60, 0]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Status + Card + Micro-Task + Breathe (unified block)
                if let card = todaysCard {
                    Section {
                        VStack(spacing: 2) {
                            // Status bar
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
                                } else if let sleepUntil = settings.activeTimeWindow.nextWindowStart() {
                                    Text(String(localized: "zzz \(formatTime(sleepUntil))"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else if let nextDate = scheduler.nextNotificationDate {
                                    Text(formatTime(nextDate))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(ProgressTracker.shared.todayCompleted)/\(ProgressTracker.shared.todayTriggered)")
                                    .font(.system(size: 11).monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)

                            // Card banner with title + ☯ breathe shortcut
                            HStack(spacing: 0) {
                                Text(card.localizedTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                // Breathe shortcut on the right
                                Button {
                                    showingBlackout = true
                                } label: {
                                    Text("☯")
                                        .font(.system(size: 36))
                                        .grayscale(1.0)
                                        .opacity(0.7)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { showingCardDetail = true }
                            .background(
                                WatchCardBackground(color: card.color)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Micro-task below card
                            if let task = currentTask {
                                Rectangle()
                                    .fill(card.color.opacity(0.4))
                                    .frame(width: 2, height: 4)

                                Text(task.localizedText)
                                    .font(.system(size: 10).italic())
                                    .foregroundColor(.primary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(card.color.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(card.color.opacity(0.2), lineWidth: 0.5)
                                    )
                                    .onTapGesture { showingCardDetail = true }
                            }

                            // Breathe now button — directly below the card/task
                            Button {
                                showingBlackout = true
                            } label: {
                                Label(String(localized: "Breathe now"), systemImage: "play.circle")
                                    .font(.callout)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .contentShape(Rectangle())
                            .padding(.top, 12)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    }
                    .sheet(isPresented: $showingCardDetail) {
                        WatchCardDetailView(card: card)
                    }
                } else {
                    // Fallback: status bar + breathe button when no card assigned
                    Section {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                if settings.isSnoozed {
                                    if let until = settings.snoozeUntil, until < Date.distantFuture {
                                        Text(formatTime(until)).font(.system(size: 11)).foregroundColor(.orange)
                                    } else {
                                        Text(String(localized: "Paused")).font(.system(size: 11)).foregroundColor(.orange)
                                    }
                                } else if let sleepUntil = settings.activeTimeWindow.nextWindowStart() {
                                    Text(String(localized: "zzz \(formatTime(sleepUntil))")).font(.system(size: 11)).foregroundColor(.secondary)
                                } else if let nextDate = scheduler.nextNotificationDate {
                                    Text(formatTime(nextDate)).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(ProgressTracker.shared.todayCompleted)/\(ProgressTracker.shared.todayTriggered)")
                                    .font(.system(size: 11).monospacedDigit()).foregroundColor(.secondary)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))

                            Button {
                                showingBlackout = true
                            } label: {
                                Label(String(localized: "Breathe now"), systemImage: "play.circle")
                                    .font(.footnote)
                            }
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .navigationTitle(String(localized: "Atempause"))
            .fullScreenCover(isPresented: $showingBlackout) {
                BlackoutView(isPresented: $showingBlackout)
            }
            .task {
                // Prefer iOS-synced card (storedPracticeCard) over local random assignment
                // to ensure the watch shows the same card as the phone
                todaysCard = settings.storedPracticeCard() ?? settings.todaysPracticeCard()
                currentTask = settings.currentMicroTask()
                // Ensure complication shows the same card as the app
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onReceive(settings.objectWillChange) { _ in
                // Refresh card when iOS sync updates the stored card ID
                let synced = settings.storedPracticeCard()
                if synced?.id != todaysCard?.id, let newCard = synced {
                    todaysCard = newCard
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBlackout)) { _ in
                showingBlackout = true
            }
            .onChange(of: showingBlackout) { _, isShowing in
                // When the blackout dismisses after an alarm fired, show awareness check here
                // because the system alarm UI covered the BlackoutView's awareness check
                if !isShowing && AlarmSessionManager.shared.hasFired {
                    AlarmSessionManager.shared.resetHasFired()
                    showingAwarenessCheck = true
                    withAnimation(.easeIn(duration: 0.3)) {
                        awarenessCheckOpacity = 1.0
                    }
                    // User taps a button to dismiss (handled by overlay buttons)
                }

                // Refresh state after blackout
                if !isShowing {
                    todaysCard = settings.storedPracticeCard() ?? settings.todaysPracticeCard()
                    // Rotate micro-task to a new random one after each blackout
                    currentTask = settings.rotateMicroTask()
                    // Refresh complication after blackout (card/task may have changed)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .overlay {
                // Awareness check overlay shown after alarm-dismissed blackout
                if showingAwarenessCheck {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        WatchAwarenessBar(
                            value: $overlaySliderValue,
                            onSubmit: { score in
                                handleOverlayAwarenessScore(score)
                            }
                        )
                    }
                    .opacity(awarenessCheckOpacity)
                }
            }
        }
    }

    // MARK: - Awareness Check Overlay

    /// Handle awareness score from the overlay slider
    private func handleOverlayAwarenessScore(_ score: Int) {
        ProgressTracker.shared.recordAwarenessScore(score)
        // Relay completed event with awareness score to iOS for Supabase upload
        if let start = WatchConnectivityManager.lastBlackoutStartTime {
            WatchConnectivityManager.shared.relayBlackoutEvent(
                startedAt: start,
                duration: WatchConnectivityManager.lastBlackoutDuration,
                completed: WatchConnectivityManager.lastBlackoutCompleted,
                awareness: "\(score)"
            )
        }
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeOut(duration: 0.3)) {
            awarenessCheckOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAwarenessCheck = false
        }
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

// MARK: - Watch Card Detail View

/// Compact detail view for the practice card on watchOS.
/// Shows the full title, description, and current micro-task on the card's color background.
struct WatchCardDetailView: View {
    let card: PracticeCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(card.localizedTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(card.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                // Show current micro-task if assigned (tinted background)
                if let task = SettingsManager.shared.currentMicroTask() {
                    Text(task.localizedText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(
            WatchCardBackground(color: card.color)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when the user taps a notification, triggering a blackout
    static let showBlackout = Notification.Name("showBlackout")
    /// Posted when the end-of-blackout notification fires, triggering dismiss
    static let dismissBlackout = Notification.Name("dismissBlackout")
}
