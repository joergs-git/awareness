import SwiftUI
import AVKit

/// SwiftUI view rendered inside the blackout overlay window.
/// Displays different content based on the configured visual type.
/// Text, image, and plain-black modes include a gentle breathing animation.
struct BlackoutContentView: View {

    let visualType: BlackoutVisualType
    let customText: String
    let imagePath: String
    let videoPath: String

    /// Controls the breathing animation — toggled on after a short delay to start pulsing
    @State private var isBreathing = false

    init(
        visualType: BlackoutVisualType,
        customText: String = "",
        imagePath: String = "",
        videoPath: String = ""
    ) {
        self.visualType = visualType
        self.customText = customText
        self.imagePath = imagePath
        self.videoPath = videoPath
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch visualType {
            case .plainBlack:
                // Subtle breathing circle as a minimal visual anchor
                Circle()
                    .fill(Color.white.opacity(isBreathing ? 0.08 : 0.015))
                    .frame(width: isBreathing ? 20 : 12, height: isBreathing ? 20 : 12)
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: isBreathing
                    )

            case .text:
                Text(customText)
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
        .onAppear {
            // Start breathing animation after the window fade-in (2s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isBreathing = true
            }
        }
    }

    // MARK: - Image Mode

    @ViewBuilder
    private var imageContent: some View {
        if let url = SettingsManager.shared.resolveCustomImageURL(),
           let nsImage = NSImage(contentsOf: url) {
            // User-selected custom image (resolved via security-scoped bookmark)
            Image(nsImage: nsImage)
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
            // Bundled default image
            Image(nsImage: defaultImage)
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
            // Last resort fallback
            Text(String(localized: "Breathe."))
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    /// Load the bundled default-blackout.png from the SPM resource bundle
    private func loadBundledDefaultImage() -> NSImage? {
        guard let url = Bundle.main.url(
            forResource: "default-blackout",
            withExtension: "png"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }

    // MARK: - Video Mode

    @ViewBuilder
    private var videoContent: some View {
        if let url = SettingsManager.shared.resolveCustomVideoURL() {
            VideoLoopView(url: url)
        } else {
            // Fallback when no video is configured
            Text(String(localized: "No video selected"))
                .foregroundColor(.white.opacity(0.3))
                .font(.title2)
        }
    }
}

// MARK: - Post-Blackout View (Namaste → Card + Micro-Task)

/// Shown after the breathing session ends: first a namaste 🙏 (1.5s fade),
/// then the day's practice card title and a random micro-task.
/// Stays on screen until the user clicks anywhere to dismiss.
struct PostBlackoutView: View {

    @ObservedObject var state: BlackoutPhaseState

    /// Opacity for namaste fade-in/fade-out
    @State private var namasteOpacity: Double = 0
    /// Opacity for card content fade-in
    @State private var cardOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state.phase {
            case .breathing:
                EmptyView()

            case .namaste:
                Text("🙏")
                    .font(.system(size: 72))
                    .opacity(namasteOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.4)) {
                            namasteOpacity = 1.0
                        }
                    }

            case .practiceCard:
                VStack(spacing: 20) {
                    if let card = state.practiceCard {
                        Text(card.localizedTitle)
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(card.color)
                            .multilineTextAlignment(.center)

                        // Divider line in card color
                        Rectangle()
                            .fill(card.color.opacity(0.4))
                            .frame(width: 120, height: 1)
                    }

                    if let task = state.microTask {
                        Text(task.localizedText)
                            .font(.system(size: 18, weight: .light).italic())
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 60)
                    }

                    Spacer().frame(height: 40)

                    Text(String(localized: "click anywhere to continue"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                }
                .opacity(cardOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        cardOpacity = 1.0
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.phase == .practiceCard {
                state.onDismissRequest?()
            }
        }
    }
}

// MARK: - Startclick Confirmation View

/// Shown before the actual blackout when "Startclick confirmation" is enabled.
/// Lets the user accept ("Yes") or decline ("No") the breathing session.
/// Declining skips the blackout without counting it as completed.
struct BlackoutConfirmationView: View {

    /// Called when the user confirms they want to start the blackout
    var onConfirm: () -> Void
    /// Called when the user declines — blackout is skipped
    var onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Text(String(localized: "Ready to breathe?"))
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 24) {
                    // "Yes" button — starts the actual blackout
                    Button(action: onConfirm) {
                        Text(String(localized: "Yes"))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 100, height: 44)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    // "No" button — dismisses without counting as completed
                    Button(action: onDecline) {
                        Text(String(localized: "No"))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 100, height: 44)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
        }
    }
}

// MARK: - Looping Video Player (AppKit-backed)

/// NSViewRepresentable that plays a video in a loop using AVPlayerLooper
struct VideoLoopView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        // Loop the video indefinitely
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: playerItem)

        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspect
        player.play()

        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        // Hold a strong reference to keep the looper alive
        var looper: AVPlayerLooper?
    }
}
