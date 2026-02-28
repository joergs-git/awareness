import WatchKit

/// Manages a WKExtendedRuntimeSession in alarm mode to deliver a reliable
/// end-of-blackout haptic signal — even when the wrist is down and display is off.
///
/// **How it works:**
/// 1. When a blackout starts, `scheduleEndAlarm(at:)` is called with the exact end time.
///    This uses `start(at:)` which schedules the session to fire at a future date.
/// 2. When the scheduled time arrives, watchOS launches/resumes the app and calls
///    `extendedRuntimeSessionDidStart`. At this point we call `notifyUser(hapticType:repeatHandler:)`
///    which plays a haptic and shows a system alarm UI (if the app is not active).
/// 3. The haptic repeats every 10 seconds until the user taps "Stop" in the system UI
///    or the session is invalidated by the app.
///
/// **Why alarm mode instead of mindfulness:**
/// `notifyUser(hapticType:repeatHandler:)` is the ONLY API that delivers haptic feedback
/// when the wrist is down and display is off. It requires the alarm background mode
/// (`WKBackgroundModes: smart-alarm` in Info.plist) and a session scheduled with `start(at:)`.
/// Mindfulness sessions (started with `start()`) cannot use this API — all other haptic
/// methods (WKInterfaceDevice.play(), local notifications routed through willPresent) are
/// throttled when the display dims.
final class AlarmSessionManager: NSObject, WKExtendedRuntimeSessionDelegate {

    static let shared = AlarmSessionManager()

    private var session: WKExtendedRuntimeSession?

    /// Debug status string — visible in BlackoutView when the blackout ends on wrist-raise,
    /// helping diagnose whether the alarm session was properly scheduled and fired.
    private(set) var debugStatus: String = "idle"

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Schedule an alarm session to fire at the given date, delivering a haptic signal.
    /// Must be called while the app is in the foreground (e.g. when the blackout starts).
    func scheduleEndAlarm(at date: Date) {
        cancelAlarm()

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start(at: date)
        self.session = session

        let delay = date.timeIntervalSinceNow
        debugStatus = "scheduled (in \(Int(delay))s), state=\(stateString(session.state))"
        print("AlarmSession: scheduled for \(date) (\(Int(delay))s from now), state=\(stateString(session.state))")
    }

    /// Cancel a scheduled or running alarm session.
    /// Called on early dismiss (tap-to-exit) or when the blackout ends via Timer catch-up.
    func cancelAlarm() {
        guard let session = session else { return }
        let prevState = stateString(session.state)
        if session.state == .scheduled || session.state == .running {
            session.invalidate()
        }
        self.session = nil
        debugStatus = "canceled (was \(prevState))"
        print("AlarmSession: canceled (was \(prevState))")
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        debugStatus = "FIRED — calling notifyUser"
        print("AlarmSession: didStart — calling notifyUser(hapticType:repeatHandler:)")

        // The scheduled alarm time has arrived — play haptic to signal end of blackout.
        // If the app is not active (display off, wrist down), watchOS shows a system alarm
        // UI with the haptic. The haptic repeats until the user taps "Stop" or the session
        // is invalidated by the app.
        extendedRuntimeSession.notifyUser(hapticType: .notification) { _ in
            // Repeat every 10 seconds — gentle nudge until user responds
            return 10.0
        }

        // Mark the blackout as complete and trigger dismiss.
        // This dispatch may be delayed if the main RunLoop is throttled (display off),
        // but that's fine — the haptic is already playing via notifyUser above.
        // On wrist-raise, the main thread processes this and the blackout dismisses.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dismissBlackout, object: nil)
        }
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        let reasonStr: String
        switch reason {
        case .none: reasonStr = "none (normal)"
        case .sessionInProgress: reasonStr = "sessionInProgress"
        case .expired: reasonStr = "expired"
        case .resignedFrontmost: reasonStr = "resignedFrontmost"
        case .suppressedBySystem: reasonStr = "suppressedBySystem"
        case .error: reasonStr = "error"
        @unknown default: reasonStr = "unknown(\(reason.rawValue))"
        }

        debugStatus = "invalidated: \(reasonStr)"
        if let error = error {
            debugStatus += " — \(error.localizedDescription)"
        }
        print("AlarmSession: invalidated reason=\(reasonStr) error=\(error?.localizedDescription ?? "nil")")

        self.session = nil

        // If the session ended normally (user tapped "Stop" in system alarm UI),
        // make sure the blackout gets dismissed
        if reason == .none {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dismissBlackout, object: nil)
            }
        }
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        debugStatus = "willExpire"
        print("AlarmSession: willExpire")

        // Session is about to expire — ensure blackout gets dismissed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dismissBlackout, object: nil)
        }
    }

    // MARK: - Helpers

    private func stateString(_ state: WKExtendedRuntimeSessionState) -> String {
        switch state {
        case .notStarted: return "notStarted"
        case .scheduled: return "scheduled"
        case .running: return "running"
        case .invalid: return "invalid"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }
}
