import Foundation
import Combine

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
        nextBlackoutDate = Date().addingTimeInterval(delay)
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

        // Skip if camera or microphone is actively in use
        if MediaUsageDetector.shared.isMediaInUse() {
            scheduleNext()
            return
        }

        // Trigger the blackout with all configured visual settings
        blackoutController.show(
            duration: settings.blackoutDuration,
            visualType: settings.visualType,
            customText: settings.customText,
            imagePath: settings.customImagePath,
            videoPath: settings.customVideoPath
        ) { [weak self] in
            // After blackout ends, schedule the next one
            self?.scheduleNext()
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
