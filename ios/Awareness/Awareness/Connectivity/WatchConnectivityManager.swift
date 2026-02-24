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

    /// Push current settings to the companion Apple Watch
    func pushSettingsToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

        let context = SettingsManager.shared.connectivityContext()
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Settings Observation

    /// Observe local settings changes and push to the watch (debounced).
    /// Uses objectWillChange to avoid complex type-checker merge chains.
    private func observeSettingsChanges() {
        SettingsManager.shared.objectWillChange
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

    /// Receive updated settings from the companion Apple Watch
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isApplyingRemoteContext = true
            SettingsManager.shared.applyFromConnectivityContext(applicationContext)
            self.isApplyingRemoteContext = false
            // Reschedule notifications with updated settings
            NotificationScheduler.shared.rescheduleAll()
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
