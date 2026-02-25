import SwiftUI
import WatchKit

/// Full-screen blackout view for Apple Watch.
/// Shows plain black or text content, uses haptic feedback instead of audio,
/// and keeps the app alive with a WKExtendedRuntimeSession during the blackout.
struct BlackoutView: View {

    @ObservedObject var settings = SettingsManager.shared
    @Binding var isPresented: Bool

    /// The randomized duration for this blackout instance
    @State private var duration: Double = 0
    @State private var opacity: Double = 0
    @State private var dismissTimer: Timer?
    /// Tracks when the blackout started for HealthKit logging
    @State private var sessionStart: Date?
    /// Extended runtime session to keep the app alive during blackout
    @State private var extendedSession: WKExtendedRuntimeSession?
    /// Opacity of the white end-of-blackout flash layer
    @State private var flashOpacity: Double = 0
    /// Whether the blackout ran its full duration (not dismissed early)
    @State private var completedFullDuration = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Watch only supports plain black or text (no image/video)
            if settings.visualType == .text {
                Text(settings.customText)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(12)
            }

            // White flash layer — briefly visible at the end of a blackout
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
        }
        .opacity(opacity)
        .onAppear {
            sessionStart = Date()
            duration = settings.randomBlackoutDuration()
            ProgressTracker.shared.recordTriggered()

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

            // Auto-dismiss timer
            dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                completedFullDuration = true
                dismissBlackout()
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
            dismissTimer = nil
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
        dismissTimer?.invalidate()
        dismissTimer = nil

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                stopExtendedSession()
                isPresented = false
            }
        }
    }

    // MARK: - Extended Runtime Session

    /// Start a mindfulness extended runtime session to keep the app alive
    private func startExtendedSession() {
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    /// Stop the extended runtime session when the blackout ends
    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
