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

            // Auto-dismiss timer
            dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
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

        // Haptic at end
        if settings.hapticEndEnabled {
            HapticPlayer.playEnd()
        }

        // Log mindful session to HealthKit if enabled
        if settings.healthKitEnabled, let start = sessionStart {
            let end = Date()
            Task { await HealthKitManager.shared.saveMindfulSession(start: start, end: end) }
        }

        // Fade out
        withAnimation(.easeOut(duration: 1.0)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            stopExtendedSession()
            isPresented = false
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
