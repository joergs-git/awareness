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
/// (`WKBackgroundModes: alarm` in Info.plist) and a session scheduled with `start(at:)`.
/// Mindfulness sessions (started with `start()`) cannot use this API — all other haptic
/// methods (WKInterfaceDevice.play(), local notifications routed through willPresent) are
/// throttled when the display dims.
///
/// **Trade-off:** Alarm mode does NOT provide runtime during the blackout (only at the
/// scheduled time). The app is suspended when the display dims. This is acceptable because
/// the display is off anyway — the user can't see animations. The alarm fires at the exact
/// end time to deliver the haptic signal.
final class AlarmSessionManager: NSObject, WKExtendedRuntimeSessionDelegate {

    static let shared = AlarmSessionManager()

    private var session: WKExtendedRuntimeSession?

    /// Debug status string — persisted to UserDefaults so it survives app suspension.
    /// Visible on ContentView to help diagnose alarm session behavior.
    private(set) var debugStatus: String = "idle"

    /// Key for persisting the debug log to UserDefaults
    private static let debugLogKey = "alarmDebugLog"

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Schedule an alarm session to fire at the given date, delivering a haptic signal.
    /// Must be called while the app is in the foreground (e.g. when the blackout starts).
    func scheduleEndAlarm(at date: Date) {
        cancelAlarm()
        clearDebugLog()

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start(at: date)
        self.session = session

        let delay = date.timeIntervalSinceNow
        log("scheduled (in \(Int(delay))s), state=\(stateString(session.state))")
    }

    /// Cancel a scheduled or running alarm session.
    /// Called on early dismiss (tap-to-exit) or in onDisappear for cleanup.
    func cancelAlarm() {
        guard let session = session else { return }
        let prevState = stateString(session.state)
        if session.state == .scheduled || session.state == .running {
            session.invalidate()
        }
        self.session = nil
        log("canceled (was \(prevState))")
    }

    // MARK: - Debug Log (persisted to UserDefaults)

    /// Returns the persisted debug log entries for display in the UI.
    static func debugLog() -> [String] {
        UserDefaults.standard.stringArray(forKey: debugLogKey) ?? []
    }

    /// Clear the debug log (called when a new alarm is scheduled).
    func clearDebugLog() {
        UserDefaults.standard.removeObject(forKey: AlarmSessionManager.debugLogKey)
    }

    /// Log a message to both console and persisted UserDefaults log.
    private func log(_ message: String) {
        debugStatus = message
        print("AlarmSession: \(message)")

        // Persist to UserDefaults so the log survives app suspension/relaunch
        var logs = UserDefaults.standard.stringArray(forKey: AlarmSessionManager.debugLogKey) ?? []
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let timestamp = formatter.string(from: Date())
        logs.append("[\(timestamp)] \(message)")
        // Keep last 10 entries to avoid unbounded growth
        if logs.count > 10 { logs = Array(logs.suffix(10)) }
        UserDefaults.standard.set(logs, forKey: AlarmSessionManager.debugLogKey)
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        log("FIRED — calling notifyUser")

        // The scheduled alarm time has arrived — play a single gentle haptic to signal
        // end of blackout. If the app is not active (display off, wrist down), watchOS
        // shows a system alarm UI. We use .directionUp for a soft, uplifting feel and
        // return 0 to play just once (no repeating alarm — keeps it calm).
        //
        // The system alarm UI appearance is controlled by watchOS and cannot be customized.
        // It's the unavoidable cost of the only API that delivers haptics wrist-down.
        //
        // IMPORTANT: Do NOT post .dismissBlackout or call cancelAlarm() here!
        // Doing so would invalidate the session on the next run loop iteration,
        // killing the notifyUser haptic before it plays even one pulse.
        // The Timer in BlackoutView handles the visual dismiss on wrist-raise.
        // The alarm's only job is delivering the haptic signal.
        extendedRuntimeSession.notifyUser(hapticType: .directionUp) { _ in
            // Return 0 = play once and stop. No repeating alarm — just a calm nudge.
            return 0
        }

        log("notifyUser called, session state=\(stateString(extendedRuntimeSession.state))")
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

        var msg = "invalidated: \(reasonStr)"
        if let error = error {
            msg += " — \(error.localizedDescription)"
        }
        log(msg)

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
        log("willExpire")
        // No action needed — the Timer in BlackoutView handles dismiss on wrist-raise.
        // Don't invalidate the session here; let it expire naturally so notifyUser
        // can continue delivering haptics until the very end.
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
