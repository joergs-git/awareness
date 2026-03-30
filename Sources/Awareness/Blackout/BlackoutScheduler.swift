import Foundation
import Combine
import CoreGraphics

/// Schedules blackouts at random intervals within the configured range.
/// Respects the active time window and media usage detection.
/// Automatically reschedules when relevant settings change.
class BlackoutScheduler {

    private let blackoutController: BlackoutWindowController
    private let settings: SettingsManager
    private var timer: DispatchSourceTimer?
    private(set) var isRunning = false

    /// Public read-only alias for menu state
    var isCurrentlyRunning: Bool { isRunning }
    private var cancellables = Set<AnyCancellable>()

    /// The date when the next blackout is expected to fire
    private(set) var nextBlackoutDate: Date?

    /// Called whenever the next-blackout date changes (for tooltip/menu updates)
    var onNextDateChanged: ((Date?) -> Void)?

    init(blackoutController: BlackoutWindowController, settings: SettingsManager = .shared) {
        self.blackoutController = blackoutController
        self.settings = settings
        observeSettingsChanges()
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleNext()
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        nextBlackoutDate = nil
        onNextDateChanged?(nil)
    }

    // MARK: - Settings Observation

    /// Reschedule when the user changes the interval range so it takes effect immediately
    private func observeSettingsChanges() {
        // Combine the two interval publishers — reschedule whenever either changes
        settings.$minInterval
            .merge(with: settings.$maxInterval)
            .dropFirst(2)  // skip the initial values emitted on subscribe
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                self.reschedule()
            }
            .store(in: &cancellables)
    }

    /// Public entry point: reschedule with a fresh random delay if the scheduler is running.
    /// Called after system wakes from sleep/lock/screensaver so the next blackout is relative
    /// to the moment the user returned, not the stale pre-sleep schedule.
    func rescheduleIfRunning() {
        guard isRunning else { return }
        reschedule()
    }

    /// Cancel the current timer and schedule a fresh one with updated settings
    private func reschedule() {
        timer?.cancel()
        timer = nil
        scheduleNext()
    }

    // MARK: - Scheduling Logic

    private func scheduleNext() {
        guard isRunning else { return }

        let delay = randomDelay()
        let fireDate = Date().addingTimeInterval(delay)
        let window = settings.activeTimeWindow

        // If the computed fire date falls outside the active window,
        // schedule to re-check when the window opens instead
        if !window.isActive(at: fireDate) {
            nextBlackoutDate = nil
            onNextDateChanged?(nil)
            if let windowStart = window.nextWindowStart() {
                let sleepDelay = max(1, windowStart.timeIntervalSinceNow)
                let timer = DispatchSource.makeTimerSource(queue: .main)
                timer.schedule(deadline: .now() + sleepDelay)
                timer.setEventHandler { [weak self] in
                    self?.scheduleNext()
                }
                timer.resume()
                self.timer = timer
            }
            return
        }

        nextBlackoutDate = fireDate
        onNextDateChanged?(nextBlackoutDate)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            self?.timerFired()
        }
        timer.resume()
        self.timer = timer
    }

    private func timerFired() {
        guard isRunning else { return }
        nextBlackoutDate = nil
        onNextDateChanged?(nil)

        // Skip if currently snoozed
        if settings.isSnoozed {
            scheduleNext()
            return
        }

        // Check if we're within the active time window
        guard settings.activeTimeWindow.isCurrentlyActive() else {
            scheduleNext()
            return
        }

        // Skip if camera or microphone is actively in use (only when setting is enabled)
        if settings.skipDuringMediaUse && MediaUsageDetector.shared.isMediaInUse() {
            scheduleNext()
            return
        }

        // Skip if system is idle (sleeping, display off, locked, or screensaver)
        if SystemStateDetector.shared.isSystemIdle() {
            scheduleNext()
            return
        }

        // Skip if user has been idle (no mouse/keyboard input) for 5+ minutes.
        // Note: .null event type is broken on macOS 15 (Sequoia) — always returns a large
        // value regardless of actual input. Check specific event types and take the minimum.
        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let clickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let userIdleSeconds = min(mouseIdle, keyIdle, clickIdle)
        if userIdleSeconds >= 300 {
            scheduleNext()
            return
        }

        // Pre-trigger: check Supabase for recent breaks from other platforms
        Task { [weak self] in
            let shouldDefer = await SyncManager.shared.shouldDeferToRecentBreak()

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isRunning else { return }

                if shouldDefer {
                    // Another device had a break recently — reschedule
                    self.scheduleNext()
                    return
                }

                // Trigger the blackout with all configured visual settings
                self.blackoutController.show(
                    duration: self.settings.randomBlackoutDuration(),
                    visualType: self.settings.visualType,
                    customText: self.settings.resolvedBreathingText(),
                    imagePath: self.settings.customImagePath,
                    videoPath: self.settings.customVideoPath
                ) { [weak self] in
                    // After blackout ends, schedule the next one
                    self?.scheduleNext()
                    // Pull remote events after each blackout
                    SyncManager.shared.pullAndIntegrate()
                }
            }
        }
    }

    /// Returns a random delay (in seconds) between the configured min and max intervals
    private func randomDelay() -> TimeInterval {
        let minSeconds = settings.minInterval * 60.0
        let maxSeconds = settings.maxInterval * 60.0
        guard maxSeconds > minSeconds else { return minSeconds }
        return TimeInterval.random(in: minSeconds...maxSeconds)
    }
}
