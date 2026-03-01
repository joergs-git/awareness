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
    /// Whether to show the namaste confirmation after blackout ends
    @State private var showingNamaste = false
    /// Controls the breathing animation — toggled on after fade-in to start pulsing
    @State private var isBreathing = false
    /// Guards against double-dismiss from both timer and notification signal
    @State private var isDismissing = false

    var body: some View {
        // TimelineView(.animation) signals to watchOS that this view needs continuous rendering.
        // This extends the time before the display dims and keeps animations updating at ~1Hz
        // even in Always-On Display state, improving the meditation experience.
        TimelineView(.animation(minimumInterval: 1.0, paused: false)) { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                // Breathing content — keeps the display active and provides a meditation focus.
                if settings.visualType == .text {
                    Text(settings.customText)
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
                    // Plain black mode — subtle breathing circle as a minimal visual anchor
                    Circle()
                        .fill(Color.white.opacity(isBreathing ? 0.10 : 0.02))
                        .frame(width: isBreathing ? 12 : 8, height: isBreathing ? 12 : 8)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: isBreathing
                        )
                }

                // White flash layer — briefly visible at the end of a blackout
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)

                // Namaste confirmation shown after blackout fades out
                if showingNamaste {
                    Text("🙏")
                        .font(.system(size: 48))
                        .transition(.opacity)
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            sessionStart = Date()
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
        // Allow tap to dismiss unless handcuffs mode is on
        .onTapGesture {
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
        // When the alarm fired, the system alarm UI covers our view — namaste
        // would be invisible here. Skip it and let ContentView show it instead.
        let alarmFired = AlarmSessionManager.shared.hasFired
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 0
            }
            if alarmFired {
                // Quick dismiss — ContentView will show the namaste
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPresented = false
                }
            } else {
                // Normal flow — show namaste here before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 1.0
                        showingNamaste = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - End Signal Notification

    /// Schedule a local notification as a backup end signal.
    /// The primary signal is the alarm session (AlarmSessionManager). This notification
    /// acts as a fallback in case the alarm session fails to start or fire.
    private func scheduleEndSignalNotification(after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.body = String(localized: "Blackout complete")
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
