import SwiftUI
import AVKit

/// SwiftUI view rendered inside the blackout overlay window.
/// Displays different content based on the configured visual type.
/// Text and plain-black modes include a gentle breathing animation.
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
        } else if let defaultImage = loadBundledDefaultImage() {
            // Bundled default image
            Image(nsImage: defaultImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
