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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch settings.visualType {
            case .plainBlack:
                EmptyView()

            case .text:
                Text(settings.customText)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(40)

            case .image:
                imageContent

            case .video:
                videoContent
            }

            // White flash layer — briefly visible at the end of a blackout
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
        }
        .opacity(opacity)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
            // Tap to dismiss early (disabled in handcuffs mode)
            guard !settings.handcuffsMode else { return }
            dismissBlackout()
        }
        .onAppear {
            sessionStart = Date()
            duration = settings.randomBlackoutDuration()
            GongPlayer.shared.playStartIfEnabled()

            // Haptic feedback at start
            if settings.vibrationEnabled {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }

            // Fade in
            withAnimation(.easeIn(duration: 2.0)) {
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
        }
    }

    // MARK: - Dismiss

    private func dismissBlackout() {
        dismissTimer?.invalidate()
        dismissTimer = nil
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
            withAnimation(.easeOut(duration: 2.0)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isPresented = false
            }
        }
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
        } else if let defaultImage = loadBundledDefaultImage() {
            Image(uiImage: defaultImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Breathe.")
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
            Text("No video selected")
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
