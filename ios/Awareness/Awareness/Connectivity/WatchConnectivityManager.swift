import WatchConnectivity
import Combine

/// iOS-side WatchConnectivity manager.
/// Pushes settings to the companion Apple Watch app via applicationContext
/// and receives settings changes from the watch.
class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    private var cancellables = Set<AnyCancellable>()

    /// Whether the paired Apple Watch is reachable
    @Published private(set) var isReachable = false

    /// Guards against pushing settings that were just received from the watch
    private var isApplyingRemoteContext = false

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

    /// Push current settings and progress to the companion Apple Watch
    func pushSettingsToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

        var context = SettingsManager.shared.connectivityContext()

        // Include progress stats for cross-device sync
        let progressContext = ProgressTracker.shared.connectivityContext()
        for (key, value) in progressContext {
            context[key] = value
        }

        // Include the latest fire dates for coordinated scheduling
        let timestamps = NotificationScheduler.shared.scheduledFireDates.map { $0.timeIntervalSince1970 }
        if !timestamps.isEmpty {
            context["scheduledFireDates"] = timestamps
        }

        try? WCSession.default.updateApplicationContext(context)
    }

    /// Push notification fire dates to the companion watch for coordinated scheduling
    func pushScheduleToWatch(_ fireDates: [Date]) {
        guard WCSession.default.activationState == .activated else { return }

        var context = SettingsManager.shared.connectivityContext()

        // Include progress stats
        let progressContext = ProgressTracker.shared.connectivityContext()
        for (key, value) in progressContext {
            context[key] = value
        }

        // Include fire dates as Unix timestamps
        context["scheduledFireDates"] = fireDates.map { $0.timeIntervalSince1970 }

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Settings & Progress Observation

    /// Observe local settings and progress changes and push to the watch (debounced).
    /// Uses objectWillChange to avoid complex type-checker merge chains.
    private func observeSettingsChanges() {
        SettingsManager.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushSettingsToWatch()
            }
            .store(in: &cancellables)

        // Push progress updates to watch after blackout completion
        ProgressTracker.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushSettingsToWatch()
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

    /// Receive updated settings and progress from the companion Apple Watch.
    /// If the watch's next fire date is earlier than ours, adopt it via earliest-wins.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isApplyingRemoteContext = true
            SettingsManager.shared.applyFromConnectivityContext(applicationContext)
            ProgressTracker.shared.applyFromConnectivityContext(applicationContext)
            self.isApplyingRemoteContext = false

            // Earliest-wins: if the watch's next fire date is earlier, adopt it
            if let watchTimestamp = applicationContext["nextFireDate"] as? Double {
                let watchDate = Date(timeIntervalSince1970: watchTimestamp)
                NotificationScheduler.shared.adoptEarliestDate(watchDate)
            } else {
                // No fire date from watch — reschedule with updated settings
                NotificationScheduler.shared.rescheduleAll()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    // MARK: - Required iOS WCSessionDelegate stubs

    /// Called when the session transitions to the deactivated state (iPhone only)
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to support switching between multiple watches
        session.activate()
    }

    /// Called when the session transitions to the inactive state (iPhone only)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // No action needed — awaiting deactivation
    }
}
