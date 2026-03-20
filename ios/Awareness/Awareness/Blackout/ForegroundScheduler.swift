import Foundation
import Combine

/// In-app foreground timer that triggers blackouts while the app is active.
/// Works independently of notification permission — ensures the app functions
/// even when the user denies notifications (Apple Guideline 4.5.4 compliance).
///
/// Uses the same `.showBlackout` notification mechanism as `NotificationScheduler`,
/// so the receiving side (ContentView) needs zero changes.
///
/// **Dedup thresholds:** Skips if `NotificationScheduler.nextNotificationDate` is within
/// 60s (lookahead). `willPresent` suppresses notification banner if foreground triggered
/// within 30s (lookback). Prevents double-triggering when both systems are active.
class ForegroundScheduler: ObservableObject {

    static let shared = ForegroundScheduler()

    private let settings = SettingsManager.shared
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Whether the foreground scheduler is currently running
    @Published private(set) var isRunning = false

    /// The date when the next foreground-triggered blackout is expected
    @Published private(set) var nextBlackoutDate: Date?

    /// Timestamp of the last foreground-triggered blackout (used for dedup with notifications)
    private(set) var lastTriggerDate: Date?

    private init() {
        observeSettingsChanges()
    }

    // MARK: - Start / Stop

    /// Start the foreground timer. Called when the app enters the active scene phase.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleNext()
    }

    /// Stop the foreground timer. Called when the app leaves the active scene phase.
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        nextBlackoutDate = nil
    }

    // MARK: - Settings Observation

    /// Reschedule when the user changes interval or active hours settings (debounced)
    private func observeSettingsChanges() {
        settings.$minInterval
            .merge(with: settings.$maxInterval)
            .merge(with: settings.$activeStartHour.map { Double($0) })
            .merge(with: settings.$activeEndHour.map { Double($0) })
            .dropFirst(4) // skip initial values emitted on subscribe
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                self.reschedule()
            }
            .store(in: &cancellables)

        // Observe snooze changes to pause/resume the timer
        settings.$snoozeUntil
            .dropFirst()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                self.reschedule()
            }
            .store(in: &cancellables)
    }

    // MARK: - Scheduling Logic

    /// Cancel any existing timer and schedule a fresh one
    private func reschedule() {
        timer?.invalidate()
        timer = nil
        scheduleNext()
    }

    /// Schedule the next foreground blackout at a random interval
    private func scheduleNext() {
        guard isRunning else { return }

        // If snoozed, don't schedule — the snooze observer will reschedule when it clears
        if settings.isSnoozed {
            nextBlackoutDate = nil
            return
        }

        let delay = randomDelay()
        let fireDate = Date().addingTimeInterval(delay)

        // If the computed fire date falls outside the active window,
        // schedule the timer for the next window start but don't advertise
        // a misleading "next" time — ContentView will show "Sleeping until"
        let window = settings.activeTimeWindow
        if !window.isActive(at: fireDate) {
            nextBlackoutDate = nil
            // Schedule to re-check when the window opens
            if let windowStart = window.nextWindowStart() {
                let sleepDelay = max(1, windowStart.timeIntervalSinceNow)
                timer = Timer.scheduledTimer(withTimeInterval: sleepDelay, repeats: false) { [weak self] _ in
                    self?.scheduleNext()
                }
            }
            return
        }

        nextBlackoutDate = fireDate

        // Use Timer.scheduledTimer on the main RunLoop for reliable foreground firing
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.timerFired()
        }
    }

    /// Called when the foreground timer fires
    private func timerFired() {
        guard isRunning else { return }
        nextBlackoutDate = nil

        // Skip if snoozed
        if settings.isSnoozed {
            scheduleNext()
            return
        }

        // Skip if outside the active time window
        guard settings.activeTimeWindow.isCurrentlyActive() else {
            scheduleNext()
            return
        }

        // Dedup: skip if a notification is about to fire within 60 seconds
        if let nextNotification = NotificationScheduler.shared.nextNotificationDate,
           abs(nextNotification.timeIntervalSinceNow) < 60 {
            scheduleNext()
            return
        }

        // Skip if the user is on a phone or video call — don't count as triggered
        if CallDetector.shared.shouldSkipBlackout() {
            scheduleNext()
            return
        }

        // Pre-flight: check if a break just happened on another device via Supabase.
        // If so, postpone instead of double-triggering.
        Task {
            let shouldDefer = await SyncManager.shared.shouldDeferToRecentBreak()

            await MainActor.run {
                guard self.isRunning else { return }

                if shouldDefer {
                    // Desktop break was recent — postpone
                    let minDelay = self.settings.effectiveMinInterval * 60.0
                    let extra = TimeInterval.random(in: 30...120)
                    let fireDate = Date().addingTimeInterval(minDelay + extra)
                    self.nextBlackoutDate = fireDate
                    self.timer = Timer.scheduledTimer(withTimeInterval: minDelay + extra, repeats: false) { [weak self] _ in
                        self?.timerFired()
                    }
                    return
                }

                // Fire the blackout
                self.lastTriggerDate = Date()
                ProgressTracker.shared.recordTriggered()

                NotificationCenter.default.post(name: .showBlackout, object: nil)

                // Schedule the next one
                self.scheduleNext()
            }
        }
    }

    // MARK: - Desktop Sync Postpone

    /// Postpone the next foreground blackout to at least the given date.
    /// Called by SyncManager when a recent desktop break is detected,
    /// so iOS doesn't fire a break too soon after the desktop did.
    func postponeIfNeeded(until date: Date) {
        guard isRunning else { return }
        guard let next = nextBlackoutDate, next < date else { return }

        // Cancel the current timer and reschedule to fire after the postpone date
        timer?.invalidate()
        timer = nil

        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { return }

        // Add a random extra offset (30–120s) so it doesn't fire exactly at the boundary
        let extra = TimeInterval.random(in: 30...120)
        let totalDelay = delay + extra
        let fireDate = Date().addingTimeInterval(totalDelay)
        nextBlackoutDate = fireDate

        timer = Timer.scheduledTimer(withTimeInterval: totalDelay, repeats: false) { [weak self] _ in
            self?.timerFired()
        }
    }

    // MARK: - Helpers

    /// Returns a random delay (in seconds) using effective (guru-adapted or manual) intervals
    private func randomDelay() -> TimeInterval {
        let minSeconds = settings.effectiveMinInterval * 60.0
        let maxSeconds = settings.effectiveMaxInterval * 60.0
        guard maxSeconds > minSeconds else { return minSeconds }
        return TimeInterval.random(in: minSeconds...maxSeconds)
    }
}
