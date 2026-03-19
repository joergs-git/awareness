import SwiftUI
import WatchKit
import UserNotifications

/// Full-screen blackout view for Apple Watch.
/// Shows plain black or text content with a gentle breathing animation.
///
/// **End signal strategy (alarm session):**
/// Uses `WKExtendedRuntimeSession` in **alarm mode** with `start(at:)` to schedule
/// the end-of-blackout signal at the exact end time. When the alarm fires, watchOS
/// launches/resumes the app and calls `notifyUser(hapticType:repeatHandler:)` — the ONLY
/// API that delivers haptic feedback when the wrist is down and display is off.
/// The app is NOT kept alive during the blackout (alarm mode doesn't provide runtime
/// until the scheduled time). A repeating Timer catches up via Date check on wrist-raise.
/// A local notification serves as a backup end signal.
///
/// **Namaste after alarm dismiss:** When `AlarmSessionManager.hasFired` is true, the system
/// alarm UI covers this view — so we skip the in-view namaste and dismiss immediately.
/// ContentView detects the dismiss + hasFired flag and shows the namaste overlay there instead.
struct BlackoutView: View {

    @ObservedObject var settings = SettingsManager.shared
    @Binding var isPresented: Bool

    /// The randomized duration for this blackout instance
    @State private var duration: Double = 0
    @State private var opacity: Double = 0
    /// Main-thread repeating timer that checks wall-clock time for dismiss.
    /// When the app is suspended (display dimmed), this timer is frozen. On wrist-raise
    /// the app resumes and the timer fires immediately, catching up via the Date check.
    @State private var dismissTimer: Timer?
    /// Target wall-clock time when the blackout should end (immune to timer throttling)
    @State private var targetEndDate: Date?
    /// Tracks when the blackout started for HealthKit logging
    @State private var sessionStart: Date?
    /// Opacity of the white end-of-blackout flash layer
    @State private var flashOpacity: Double = 0
    /// Whether the blackout ran its full duration (not dismissed early)
    @State private var completedFullDuration = false
    /// Whether to show the awareness check after blackout ends
    @State private var showingAwarenessCheck = false
    /// Awareness slider value (0–100, default at center)
    @State private var sliderValue: Double = 50
    /// Controls the breathing animation — toggled on after fade-in to start pulsing
    @State private var isBreathing = false
    /// Guards against double-dismiss from both timer and notification signal
    @State private var isDismissing = false
    /// Resolved breathing text (picked once at start to avoid mid-session changes)
    @State private var displayText: String = ""

    var body: some View {
        // TimelineView(.animation) signals to watchOS that this view needs continuous rendering.
        // This extends the time before the display dims and keeps animations updating at ~1Hz
        // even in Always-On Display state, improving the meditation experience.
        TimelineView(.animation(minimumInterval: 1.0, paused: false)) { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                // Breathing content — hidden once awareness check appears
                if !showingAwarenessCheck {
                    if settings.visualType == .text {
                        Text(displayText)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.white.opacity(isBreathing ? 0.8 : 0.25))
                            .scaleEffect(isBreathing ? 1.08 : 0.94)
                            .animation(
                                .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                                value: isBreathing
                            )
                            .multilineTextAlignment(.center)
                            .padding(12)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(isBreathing ? 0.10 : 0.02))
                            .frame(width: isBreathing ? 12 : 8, height: isBreathing ? 12 : 8)
                            .animation(
                                .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                                value: isBreathing
                            )
                    }
                }

                // White flash layer — briefly visible at the end of a blackout
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)

                // Awareness check shown after completed blackout fades out
                if showingAwarenessCheck {
                    WatchAwarenessBar(
                        value: $sliderValue,
                        onSubmit: { score in
                            handleWatchAwarenessScore(score)
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            sessionStart = Date()
            displayText = settings.resolvedBreathingText()
            duration = settings.randomBlackoutDuration()

            // Double chime at start — always plays, respects system mute via .ambient session
            ChimePlayer.shared.playStartChime()

            // Fade in
            withAnimation(.easeIn(duration: 1.0)) {
                opacity = 1.0
            }

            // Start breathing animation after fade-in completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isBreathing = true
            }

            // Auto-dismiss using Date-based checking. When the app is suspended (display dims),
            // this timer is frozen. On wrist-raise the app resumes and the timer fires
            // immediately, catching up via the Date comparison.
            let endDate = Date().addingTimeInterval(duration)
            targetEndDate = endDate
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                guard let target = targetEndDate else { return }
                if Date() >= target {
                    timer.invalidate()
                    completedFullDuration = true
                    dismissBlackout()
                }
            }

            // PRIMARY end signal: alarm session scheduled for the exact end time.
            // Uses WKExtendedRuntimeSession in alarm mode — at the scheduled time, watchOS
            // launches/resumes the app and calls notifyUser(hapticType:repeatHandler:) which
            // delivers haptic feedback even when the wrist is down and display is off.
            AlarmSessionManager.shared.scheduleEndAlarm(at: endDate)

            // BACKUP end signal: local notification (in case the alarm session fails)
            scheduleEndSignalNotification(after: duration)
        }
        .onDisappear {
            dismissTimer?.invalidate()
            dismissTimer = nil
            targetEndDate = nil
            AlarmSessionManager.shared.cancelAlarm()
            cancelEndSignalNotification()
            ChimePlayer.shared.stop()
        }
        // Handle end-of-blackout notification — posted by the notification delegate
        // when the system delivers the end-signal notification (if app is still in foreground)
        .onReceive(NotificationCenter.default.publisher(for: .dismissBlackout)) { _ in
            completedFullDuration = true
            dismissBlackout()
        }
        // Allow tap to dismiss unless handcuffs mode is on or awareness check is showing
        .onTapGesture {
            guard !showingAwarenessCheck else { return }
            guard !settings.handcuffsMode else { return }
            dismissBlackout()
        }
    }

    // MARK: - Dismiss

    private func dismissBlackout() {
        // Guard against double-dismiss (timer + notification signal can race)
        guard !isDismissing else { return }
        isDismissing = true

        dismissTimer?.invalidate()
        dismissTimer = nil
        targetEndDate = nil
        // Don't cancel alarm here — if notifyUser is delivering haptics, let it continue
        // through the fade-out animation. The alarm is cleaned up in onDisappear.
        cancelEndSignalNotification()

        // Stop breathing animation
        isBreathing = false

        // Record completion only if the blackout ran its full duration
        if completedFullDuration {
            ProgressTracker.shared.recordCompleted()
        }

        // Store metadata for ContentView alarm awareness relay
        WatchConnectivityManager.lastBlackoutStartTime = sessionStart
        WatchConnectivityManager.lastBlackoutDuration = sessionStart.map { Date().timeIntervalSince($0) } ?? duration
        WatchConnectivityManager.lastBlackoutCompleted = completedFullDuration

        // Relay event to iOS for Supabase upload (early dismiss only — completed blackouts
        // wait for awareness response before relaying)
        if !completedFullDuration, let start = sessionStart {
            WatchConnectivityManager.shared.relayBlackoutEvent(
                startedAt: start,
                duration: Date().timeIntervalSince(start),
                completed: false,
                awareness: nil
            )
        }

        // Haptic at end
        if settings.hapticEndEnabled {
            HapticPlayer.playEnd()
        }

        // Log mindful session to HealthKit if enabled
        if settings.healthKitEnabled, let start = sessionStart {
            let end = Date()
            Task { await HealthKitManager.shared.saveMindfulSession(start: start, end: end) }
        }

        // White flash before fade-out (visible through closed eyelids)
        if settings.endFlashEnabled {
            withAnimation(.easeIn(duration: 0.15)) {
                flashOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.15)) {
                    flashOpacity = 0
                }
            }
        }

        // Delay fade-out when flash is active so the flash completes first
        let fadeDelay = settings.endFlashEnabled ? 1.3 : 0.0
        // When the alarm fired, the system alarm UI covers our view — awareness check
        // would be invisible here. Skip it and let ContentView show it instead.
        let alarmFired = AlarmSessionManager.shared.hasFired
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) {
            if completedFullDuration && !alarmFired {
                // Timer won the race — cancel alarm so it can't fire during async chain
                // and set hasFired to true later, which would cause a double awareness check
                AlarmSessionManager.shared.cancelAlarm()
                // Show awareness check
                withAnimation(.easeOut(duration: 0.8)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 1.0
                        showingAwarenessCheck = true
                    }
                    // User taps a button to dismiss (handled by watchAwarenessButton)
                }
            } else if alarmFired && completedFullDuration {
                // Quick dismiss — ContentView will show the awareness check
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPresented = false
                }
            } else {
                // Early dismiss — no awareness check
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPresented = false
                }
            }
        }
    }

    /// Record awareness score and dismiss
    private func handleWatchAwarenessScore(_ score: Int) {
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
        // Reset hasFired before dismissing — prevents ContentView.onChange from
        // showing a second awareness check if the alarm fired during our async chain
        AlarmSessionManager.shared.resetHasFired()
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    // MARK: - End Signal Notification

    /// Schedule a local notification as a backup end signal.
    /// The primary signal is the alarm session (AlarmSessionManager). This notification
    /// acts as a fallback in case the alarm session fails to start or fire.
    private func scheduleEndSignalNotification(after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.body = String(localized: "Break complete")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationScheduler.endSignalIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel the end-signal notification (early dismiss or blackout already ended)
    private func cancelEndSignalNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationScheduler.endSignalIdentifier]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [NotificationScheduler.endSignalIdentifier]
        )
    }
}
