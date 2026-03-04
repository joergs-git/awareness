import WatchConnectivity
import Combine
import WidgetKit

/// watchOS-side WatchConnectivity manager.
/// Receives settings from the companion iPhone app via applicationContext
/// and pushes watch settings changes back to the phone.
class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    private var cancellables = Set<AnyCancellable>()

    /// Whether the paired iPhone is reachable
    @Published private(set) var isReachable = false

    /// Guards against pushing settings that were just received from the phone.
    /// Also checked by NotificationScheduler to skip spurious rescheduling during sync.
    private(set) var isApplyingRemoteContext = false

    /// Timestamp of the last remote context application, used to prevent debounced
    /// observers from pushing stale settings back after the flag is cleared
    private var lastRemoteContextDate: Date?

    private override init() {
        super.init()
    }

    /// Activate the WCSession — call once on app launch
    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        observeSettingsChanges()
    }

    /// Push current settings and progress to the companion iPhone.
    /// The watch does NOT send fire dates back — iOS is the master scheduler.
    func pushSettingsToPhone() {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

        var context = SettingsManager.shared.connectivityContext()

        // Include progress stats for cross-device sync
        let progressContext = ProgressTracker.shared.connectivityContext()
        for (key, value) in progressContext {
            context[key] = value
        }

        // Include archived self-reports for cross-device sync
        let selfReportContext = EventStore.shared.selfReportConnectivityContext()
        for (key, value) in selfReportContext {
            context[key] = value
        }

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Settings & Progress Observation

    /// Observe local settings and progress changes and push to the phone (debounced).
    /// Skips pushing when a remote context was recently applied — the debounce fires
    /// after the isApplyingRemoteContext flag is already cleared, so we also check
    /// the timestamp to prevent echo pushes from the same sync cycle.
    private func observeSettingsChanges() {
        SettingsManager.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isApplyingRemoteContext else { return }
                guard self.lastRemoteContextDate == nil ||
                      Date().timeIntervalSince(self.lastRemoteContextDate!) >= 2.0 else { return }
                self.pushSettingsToPhone()
            }
            .store(in: &cancellables)

        // Push progress updates to phone after blackout completion
        ProgressTracker.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isApplyingRemoteContext else { return }
                guard self.lastRemoteContextDate == nil ||
                      Date().timeIntervalSince(self.lastRemoteContextDate!) >= 2.0 else { return }
                self.pushSettingsToPhone()
            }
            .store(in: &cancellables)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    /// Receive updated settings, fire dates, and progress from the companion iPhone.
    /// iOS is the master scheduler — the watch adopts its fire dates when available.
    /// Only falls back to independent scheduling if no future dates are provided.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isApplyingRemoteContext = true
            self.lastRemoteContextDate = Date()
            NotificationScheduler.shared.isApplyingRemoteContext = true
            SettingsManager.shared.applyFromConnectivityContext(applicationContext)
            ProgressTracker.shared.applyFromConnectivityContext(applicationContext)
            EventStore.shared.applyFromSelfReportContext(applicationContext)

            // Apply coordinated fire dates from iOS (master scheduler) if available
            if let timestamps = applicationContext["scheduledFireDates"] as? [Double] {
                let dates = timestamps.map { Date(timeIntervalSince1970: $0) }
                NotificationScheduler.shared.applyCoordinatedSchedule(dates)
            } else {
                // No fire dates from iOS — schedule independently as fallback
                NotificationScheduler.shared.rescheduleAll()
            }

            // Refresh complication so it shows the same practice card as the app
            WidgetCenter.shared.reloadAllTimelines()

            // Clear flags AFTER scheduling to prevent the debounced observer
            // from triggering a redundant reschedule or push back to the phone
            self.isApplyingRemoteContext = false
            NotificationScheduler.shared.isApplyingRemoteContext = false
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
