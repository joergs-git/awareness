import WatchConnectivity
import Combine

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
    /// Includes the watch's next fire date so iOS can adopt the earlier time.
    func pushSettingsToPhone() {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

        var context = SettingsManager.shared.connectivityContext()

        // Include progress stats for cross-device sync
        let progressContext = ProgressTracker.shared.connectivityContext()
        for (key, value) in progressContext {
            context[key] = value
        }

        // Include the watch's next fire date for earliest-wins negotiation
        if let nextDate = NotificationScheduler.shared.nextNotificationDate {
            context["nextFireDate"] = nextDate.timeIntervalSince1970
        }

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Settings & Progress Observation

    /// Observe local settings and progress changes and push to the phone (debounced).
    /// Uses objectWillChange to avoid complex type-checker merge chains.
    private func observeSettingsChanges() {
        SettingsManager.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushSettingsToPhone()
            }
            .store(in: &cancellables)

        // Push progress updates to phone after blackout completion
        ProgressTracker.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushSettingsToPhone()
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

    /// Receive updated settings, fire dates, and progress from the companion iPhone app
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isApplyingRemoteContext = true
            NotificationScheduler.shared.isApplyingRemoteContext = true
            SettingsManager.shared.applyFromConnectivityContext(applicationContext)
            ProgressTracker.shared.applyFromConnectivityContext(applicationContext)
            self.isApplyingRemoteContext = false
            NotificationScheduler.shared.isApplyingRemoteContext = false

            // Apply coordinated fire dates from iOS if available
            if let timestamps = applicationContext["scheduledFireDates"] as? [Double] {
                let dates = timestamps.map { Date(timeIntervalSince1970: $0) }
                NotificationScheduler.shared.applyCoordinatedSchedule(dates)
            } else {
                // No fire dates in context — reschedule independently
                NotificationScheduler.shared.rescheduleAll()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
