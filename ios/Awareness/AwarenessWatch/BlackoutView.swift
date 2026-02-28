import SwiftUI
import WatchKit

/// Delegate for WKExtendedRuntimeSession lifecycle management.
/// Detects session expiration so the blackout can end gracefully instead of
/// silently stalling with no haptic feedback.
class ExtendedSessionDelegate: NSObject, WKExtendedRuntimeSessionDelegate {

    var onExpiration: (() -> Void)?

    /// Tracks whether the session actually started running.
    /// If the session fails to start (e.g. on simulator, or configuration issue),
    /// didInvalidate fires immediately — we must NOT dismiss in that case.
    private var sessionDidStart = false

    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        sessionDidStart = true
    }

    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        // Session about to expire — trigger dismiss so end haptics still fire
        DispatchQueue.main.async { [weak self] in
            self?.onExpiration?()
        }
    }

    func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // Only dismiss if the session was previously running — startup failures
        // should not end the blackout (the timer handles dismissal regardless)
        guard sessionDidStart else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onExpiration?()
        }
    }
}

/// Full-screen blackout view for Apple Watch.
/// Shows plain black or text content with a gentle breathing animation,
/// uses haptic feedback instead of audio, and keeps the app alive with
/// a WKExtendedRuntimeSession during the blackout.
struct BlackoutView: View {

    @ObservedObject var settings = SettingsManager.shared
    @Binding var isPresented: Bool

    /// The randomized duration for this blackout instance
    @State private var duration: Double = 0
    @State private var opacity: Double = 0
    /// Background-queue timer for reliable end-of-blackout firing.
    /// Uses DispatchSourceTimer instead of Timer.scheduledTimer because the main RunLoop
    /// gets throttled when watchOS dims the display — DispatchSource on a background queue
    /// fires reliably regardless of display state.
    @State private var dismissTimer: DispatchSourceTimer?
    /// Tracks when the blackout started for HealthKit logging
    @State private var sessionStart: Date?
    /// Extended runtime session to keep the app alive during blackout
    @State private var extendedSession: WKExtendedRuntimeSession?
    /// Delegate for session lifecycle (must be retained alongside the session)
    @State private var sessionDelegate: ExtendedSessionDelegate?
    /// Opacity of the white end-of-blackout flash layer
    @State private var flashOpacity: Double = 0
    /// Whether the blackout ran its full duration (not dismissed early)
    @State private var completedFullDuration = false
    /// Whether to show the namaste confirmation after blackout ends
    @State private var showingNamaste = false
    /// Controls the breathing animation — toggled on after fade-in to start pulsing
    @State private var isBreathing = false
    /// Guards against double-dismiss from both timer and session expiration
    @State private var isDismissing = false

    var body: some View {
        // TimelineView(.animation) signals to watchOS that this view needs continuous rendering.
        // This extends the time before the display dims and keeps animations updating at ~1Hz
        // even in Always-On Display state, improving the meditation experience.
        TimelineView(.animation(minimumInterval: 1.0, paused: false)) { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                // Breathing content — keeps the display active and provides a meditation focus.
                // The continuous animation signals to watchOS that the view is dynamic,
                // which helps prevent aggressive display dimming on Always-On Display watches.
                if settings.visualType == .text {
                    Text(settings.customText)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.white.opacity(isBreathing ? 0.8 : 0.25))
                        .scaleEffect(isBreathing ? 1.08 : 0.94)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: isBreathing
                        )
                        .multilineTextAlignment(.center)
                        .padding(12)
                } else {
                    // Plain black mode — subtle breathing circle as a minimal visual anchor
                    Circle()
                        .fill(Color.white.opacity(isBreathing ? 0.10 : 0.02))
                        .frame(width: isBreathing ? 12 : 8, height: isBreathing ? 12 : 8)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: isBreathing
                        )
                }

                // White flash layer — briefly visible at the end of a blackout
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)

                // Namaste confirmation shown after blackout fades out
                if showingNamaste {
                    Text("🙏")
                        .font(.system(size: 48))
                        .transition(.opacity)
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            sessionStart = Date()
            duration = settings.randomBlackoutDuration()

            // Start extended runtime session to prevent suspension
            startExtendedSession()

            // Double chime at start + near-silent keep-alive tone for the blackout duration.
            // Keeping AVAudioEngine active signals to watchOS that the app has an active audio
            // session, which gives the process better scheduling priority and reduces timer
            // throttling when the display dims. Respects system mute via .ambient session.
            ChimePlayer.shared.playStartChimeWithKeepAlive(duration: duration)

            // Fade in
            withAnimation(.easeIn(duration: 1.0)) {
                opacity = 1.0
            }

            // Start breathing animation after fade-in completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isBreathing = true
            }

            // One-shot timer on a background queue for reliable end-of-blackout firing.
            // DispatchSourceTimer is immune to main RunLoop throttling that occurs when
            // watchOS dims the display — it fires on time regardless of display state.
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
            timer.schedule(deadline: .now() + duration)
            timer.setEventHandler { [self] in
                DispatchQueue.main.async {
                    completedFullDuration = true
                    dismissBlackout()
                }
            }
            timer.resume()
            dismissTimer = timer
        }
        .onDisappear {
            dismissTimer?.cancel()
            dismissTimer = nil
            ChimePlayer.shared.stop()
            stopExtendedSession()
        }
        // Allow tap to dismiss unless handcuffs mode is on
        .onTapGesture {
            guard !settings.handcuffsMode else { return }
            dismissBlackout()
        }
    }

    // MARK: - Dismiss

    private func dismissBlackout() {
        // Guard against double-dismiss (timer + session expiration can race)
        guard !isDismissing else { return }
        isDismissing = true

        dismissTimer?.cancel()
        dismissTimer = nil

        // Stop breathing animation
        isBreathing = false

        // Record completion only if the blackout ran its full duration
        if completedFullDuration {
            ProgressTracker.shared.recordCompleted()
        }

        // Haptic at end
        if settings.hapticEndEnabled {
            HapticPlayer.playEnd()
        }

        // Log mindful session to HealthKit if enabled
        if settings.healthKitEnabled, let start = sessionStart {
            let end = Date()
            Task { await HealthKitManager.shared.saveMindfulSession(start: start, end: end) }
        }

        // White flash before fade-out (visible through closed eyelids)
        if settings.endFlashEnabled {
            withAnimation(.easeIn(duration: 0.15)) {
                flashOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.15)) {
                    flashOpacity = 0
                }
            }
        }

        // Delay fade-out when flash is active so the flash completes first
        let fadeDelay = settings.endFlashEnabled ? 1.3 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 0
            }
            // After fade-out, show namaste confirmation briefly before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                    showingNamaste = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        stopExtendedSession()
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Extended Runtime Session

    /// Start a mindfulness extended runtime session to keep the app alive.
    /// Sets a delegate to detect session expiration — without a delegate,
    /// the session can silently expire and haptics won't fire at the end.
    private func startExtendedSession() {
        let delegate = ExtendedSessionDelegate()
        delegate.onExpiration = { [self] in
            // Session expired — trigger dismiss so end haptics still fire
            if !isDismissing {
                completedFullDuration = true
                dismissBlackout()
            }
        }
        sessionDelegate = delegate

        let session = WKExtendedRuntimeSession()
        session.delegate = delegate
        session.start()
        extendedSession = session
    }

    /// Stop the extended runtime session when the blackout ends
    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
        sessionDelegate = nil
    }
}
