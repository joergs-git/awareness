import Foundation
import CallKit

/// Detects active phone and VoIP calls using CXCallObserver.
/// Used to skip blackouts (and avoid counting them as triggered) when the user
/// is on a phone call, FaceTime, or any CallKit-integrated VoIP app (Zoom, Teams, WhatsApp, etc).
///
/// CXCallObserver does NOT require the CallKit entitlement — it only observes call state,
/// it does not intercept or modify calls. Safe for App Store submission.
final class CallDetector: NSObject, ObservableObject {

    static let shared = CallDetector()

    private let callObserver = CXCallObserver()

    /// Whether a call is currently active (ringing, dialing, or connected)
    @Published private(set) var isOnCall = false

    private override init() {
        super.init()
        callObserver.setDelegate(self, queue: .main)
        // Check initial state — there might already be an active call
        updateCallState()
    }

    /// Returns true if the user should not be interrupted (on a call and skip setting is on)
    func shouldSkipBlackout() -> Bool {
        return SettingsManager.shared.skipDuringCalls && isOnCall
    }

    /// Update state from current calls snapshot
    private func updateCallState() {
        isOnCall = callObserver.calls.contains { !$0.hasEnded }
    }
}

// MARK: - CXCallObserverDelegate

extension CallDetector: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        updateCallState()
    }
}
