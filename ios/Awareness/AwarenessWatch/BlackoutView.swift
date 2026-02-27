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
    @State private var dismissTimer: Timer?
    /// Target wall-clock time when the blackout should end (immune to timer throttling)
    @State private var targetEndDate: Date?
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
        .opacity(opacity)
        .onAppear {
            sessionStart = Date()
            duration = settings.randomBlackoutDuration()

            // Start extended runtime session to prevent suspension
            startExtendedSession()

            // Haptic at start
            if settings.hapticStartEnabled {
                HapticPlayer.playStart()
            }

            // Fade in
            withAnimation(.easeIn(duration: 1.0)) {
                opacity = 1.0
            }

            // Start breathing animation after fade-in completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isBreathing = true
            }

            // Auto-dismiss using Date-based checking to avoid watchOS timer throttling.
            // A repeating 1s timer checks against the wall-clock target, ensuring
            // the blackout doesn't overshoot even if timers are delayed by display dimming.
            targetEndDate = Date().addingTimeInterval(duration)
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                guard let target = targetEndDate else { return }
                if Date() >= target {
                    timer.invalidate()
                    completedFullDuration = true
                    dismissBlackout()
                }
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
            dismissTimer = nil
            targetEndDate = nil
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

        dismissTimer?.invalidate()
        dismissTimer = nil
        targetEndDate = nil

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
