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

    /// Guards against pushing settings that were just received from the phone
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

    /// Push current settings to the companion iPhone
    func pushSettingsToPhone() {
        guard WCSession.default.activationState == .activated else { return }
        guard !isApplyingRemoteContext else { return }

        let context = SettingsManager.shared.connectivityContext()
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Settings Observation

    /// Observe local settings changes and push to the phone (debounced).
    /// Uses objectWillChange to avoid complex type-checker merge chains.
    private func observeSettingsChanges() {
        SettingsManager.shared.objectWillChange
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

    /// Receive updated settings from the companion iPhone app
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
}
