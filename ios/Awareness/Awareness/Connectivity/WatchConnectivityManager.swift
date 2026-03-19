import WatchConnectivity
import Combine

/// iOS-side WatchConnectivity manager.
/// Pushes settings to the companion Apple Watch app via applicationContext
/// and receives settings changes from the watch.
class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    private var cancellables = Set<AnyCancellable>()

    /// Whether an Apple Watch is paired to this iPhone
    @Published private(set) var isPaired = false

    /// Whether the Atempause watch app is installed
    @Published private(set) var isWatchAppInstalled = false

    /// Whether the paired Apple Watch is reachable
    @Published private(set) var isReachable = false

    /// Guards against pushing settings that were just received from the watch
    private var isApplyingRemoteContext = false

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

    /// Push notification fire dates to the companion watch for coordinated scheduling.
    /// iOS is the master scheduler — the watch always uses these dates when available.
    func pushScheduleToWatch(_ fireDates: [Date]) {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

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
                self.pushSettingsToWatch()
            }
            .store(in: &cancellables)

        // Push progress updates to watch after blackout completion
        ProgressTracker.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isApplyingRemoteContext else { return }
                guard self.lastRemoteContextDate == nil ||
                      Date().timeIntervalSince(self.lastRemoteContextDate!) >= 2.0 else { return }
                self.pushSettingsToWatch()
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
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    /// Receive updated settings and progress from the companion Apple Watch.
    /// iOS is the master scheduler — it does not adopt fire dates from the watch.
    /// After applying settings changes, reschedule and push the new schedule to the watch.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isApplyingRemoteContext = true
            self.lastRemoteContextDate = Date()
            SettingsManager.shared.applyFromConnectivityContext(applicationContext)
            ProgressTracker.shared.applyFromConnectivityContext(applicationContext)
            self.isApplyingRemoteContext = false

            // Reschedule with (potentially updated) settings and push to watch
            NotificationScheduler.shared.rescheduleAll()
        }
    }

    /// Receive blackout event relays from the companion Apple Watch.
    /// Each transfer represents a completed (or dismissed) watchOS blackout that should
    /// be uploaded to Supabase so other platforms can coordinate triggers.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["watchBlackoutEvent"] as? Bool == true,
              let startedAtTimestamp = userInfo["startedAt"] as? Double,
              let duration = userInfo["duration"] as? Double,
              let completed = userInfo["completed"] as? Bool else { return }

        let startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        let awareness = userInfo["awareness"] as? String

        SyncManager.shared.recordEvent(
            startedAt: startedAt,
            duration: duration,
            completed: completed,
            awareness: awareness,
            source: "watchos"
        )
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
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
