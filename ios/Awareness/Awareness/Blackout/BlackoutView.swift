import SwiftUI
import UIKit
import AVKit

/// Full-screen blackout view for iOS.
/// Shows different visual content based on settings, auto-dismisses after the configured duration.
/// Plays start and end gongs, supports tap-to-dismiss (unless handcuffs mode is on).
struct BlackoutView: View {

    @ObservedObject var settings = SettingsManager.shared
    @Binding var isPresented: Bool

    /// The randomized duration for this blackout instance
    @State private var duration: Double = 0
    @State private var opacity: Double = 0
    @State private var dismissTimer: Timer?
    /// Tracks when the blackout started for HealthKit logging
    @State private var sessionStart: Date?
    /// Opacity of the white end-of-blackout flash layer
    @State private var flashOpacity: Double = 0
    /// Whether the blackout ran its full duration (not dismissed early)
    @State private var completedFullDuration = false
    /// Whether to show the awareness check after blackout ends
    @State private var showingAwarenessCheck = false
    /// Awareness slider value (0–100, default at center)
    @State private var sliderValue: Double = 50
    /// Controls the breathing animation — toggled on after fade-in to start pulsing
    @State private var isBreathing = false
    /// The offered duration for event logging (captured at start)
    @State private var offeredDuration: Double = 0
    /// Resolved breathing text (picked once at start to avoid mid-session changes)
    @State private var displayText: String = ""
    /// Sync event start time (for Supabase upload — consistent across start/end upsert)
    @State private var syncEventStartTime: Date?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Breathing content — hidden once awareness check appears
            if !showingAwarenessCheck {
                switch settings.visualType {
                case .plainBlack:
                    Circle()
                        .fill(Color.white.opacity(isBreathing ? 0.08 : 0.015))
                        .frame(width: isBreathing ? 20 : 12, height: isBreathing ? 20 : 12)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: isBreathing
                        )

                case .text:
                    Text(displayText)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white.opacity(isBreathing ? 0.8 : 0.25))
                        .scaleEffect(isBreathing ? 1.06 : 0.95)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: isBreathing
                        )
                        .multilineTextAlignment(.center)
                        .padding(40)

                case .image:
                    imageContent

                case .video:
                    videoContent
                }
            }

            // White flash layer — briefly visible at the end of a blackout
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)

            // Awareness check shown after completed blackout fades out
            if showingAwarenessCheck {
                VStack(spacing: 24) {
                    Text(String(localized: "Were you there?"))
                        .font(.title2.weight(.light))
                        .foregroundColor(.white.opacity(0.85))

                    VStack(spacing: 8) {
                        HStack {
                            Text(String(localized: "No"))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(String(localized: "Yes"))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 4)

                        Slider(value: $sliderValue, in: 0...100, step: 1) { editing in
                            if !editing {
                                // Save on release
                                handleAwarenessScore(Int(sliderValue))
                            }
                        }
                        .tint(.white.opacity(0.6))
                    }
                    .frame(width: 280)
                }
                .transition(.opacity)
            }
        }
        .opacity(opacity)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
            // Don't dismiss during awareness check — buttons handle interaction
            guard !showingAwarenessCheck else { return }
            // Tap to dismiss early (disabled in handcuffs mode)
            guard !settings.handcuffsMode else { return }
            dismissBlackout()
        }
        .onAppear {
            // Prevent auto-lock while the blackout is showing
            UIApplication.shared.isIdleTimerDisabled = true

            sessionStart = Date()
            syncEventStartTime = sessionStart
            // Resolve breathing text once (random rotation for default, custom text otherwise)
            displayText = settings.resolvedBreathingText()
            // Use guru-adapted duration when Smart Guru is enabled
            duration = settings.effectiveRandomBlackoutDuration()
            offeredDuration = duration
            GongPlayer.shared.playStartIfEnabled()

            // Upload sync event at START so other platforms know a break is in progress
            if let start = syncEventStartTime {
                SyncManager.shared.recordEvent(
                    startedAt: start,
                    duration: offeredDuration,
                    completed: false,
                    awareness: nil
                )
            }

            // Haptic feedback at start
            if settings.vibrationEnabled {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }

            // Fade in
            withAnimation(.easeIn(duration: 2.0)) {
                opacity = 1.0
            }

            // Start breathing animation after fade-in completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isBreathing = true
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
            // Re-enable auto-lock when the blackout view is removed
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Dismiss

    private func dismissBlackout() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        isBreathing = false

        // Record completion only if the blackout ran its full duration
        if completedFullDuration {
            ProgressTracker.shared.recordCompleted()
        }

        // Record event for Smart Guru analysis
        let actualDuration = sessionStart.map { Date().timeIntervalSince($0) }
        let intervalFromPrev = EventStore.shared.lastEventTimestamp
            .map { Date().timeIntervalSince1970 - $0 }
        let event = MindfulEvent.create(
            outcome: completedFullDuration ? .completed : .dismissed,
            durationOffered: offeredDuration,
            durationActual: actualDuration,
            intervalFromPrevious: intervalFromPrev
        )
        EventStore.shared.record(event: event)

        // Let Smart Guru evaluate and potentially adjust scheduling
        SmartGuru.shared.evaluateAfterEvent(event)

        GongPlayer.shared.playEndIfEnabled()

        // Haptic feedback at end
        if settings.vibrationEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        // Log the mindful session to Apple Health if enabled
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
            if completedFullDuration {
                // Show awareness check — fade content out, then show the question
                withAnimation(.easeOut(duration: 1.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 1.0
                        showingAwarenessCheck = true
                    }
                    // User taps a button to dismiss (handled by awarenessButton)
                }
            } else {
                // Early dismiss — upload final sync event (no awareness check)
                uploadSyncEvent(completed: false, awareness: nil)
                // No awareness check, just fade out
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    UIApplication.shared.isIdleTimerDisabled = false
                    isPresented = false
                }
            }
        }
    }

    /// Record awareness score and dismiss
    private func handleAwarenessScore(_ score: Int) {
        ProgressTracker.shared.recordAwarenessScore(score)
        // Upload final sync event with awareness score (upserts the start event)
        uploadSyncEvent(completed: true, awareness: "\(score)")
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIApplication.shared.isIdleTimerDisabled = false
            isPresented = false
        }
    }

    // MARK: - Sync Upload

    /// Upload the current blackout state to Supabase (upserts on sync_key + started_at + source)
    private func uploadSyncEvent(completed: Bool, awareness: String?) {
        guard let start = syncEventStartTime else { return }
        let actualDuration = Date().timeIntervalSince(start)
        SyncManager.shared.recordEvent(
            startedAt: start,
            duration: actualDuration,
            completed: completed,
            awareness: awareness
        )
        SyncManager.shared.flushPending()
    }

    // MARK: - Image Content

    @ViewBuilder
    private var imageContent: some View {
        if let url = SettingsManager.resolvedURL(for: settings.customImagePath),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isBreathing ? 1.0 : 0.6)
                .scaleEffect(isBreathing ? 1.06 : 0.95)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: isBreathing
                )
        } else if let defaultImage = loadBundledDefaultImage() {
            Image(uiImage: defaultImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isBreathing ? 1.0 : 0.6)
                .scaleEffect(isBreathing ? 1.06 : 0.95)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: isBreathing
                )
        } else {
            Text(String(localized: "Breathe."))
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    /// Load the bundled default-blackout.png
    private func loadBundledDefaultImage() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "default-blackout", withExtension: "png") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Video Content

    @ViewBuilder
    private var videoContent: some View {
        if let url = SettingsManager.resolvedURL(for: settings.customVideoPath) {
            VideoLoopView(url: url)
        } else {
            Text(String(localized: "No video selected"))
                .foregroundColor(.white.opacity(0.3))
                .font(.title2)
        }
    }
}

// MARK: - Looping Video Player (UIKit-backed)

/// UIViewControllerRepresentable that plays a video in a loop using AVPlayerLooper
struct VideoLoopView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: playerItem)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        // Hold a strong reference to keep the looper alive
        var looper: AVPlayerLooper?
    }
}
