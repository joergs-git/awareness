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
            case .plainBlack, .cardPhoto:
                // Subtle breathing circle as a minimal visual anchor.
                // For .cardPhoto the card image is shown afterwards, at the break end.
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

// MARK: - Post-Blackout View (Awareness Check → Card + Micro-Task)

/// Shown after the breathing session ends: first the awareness slider "Were you there?"
/// (0–100 continuous scale), then the day's practice card title and a random micro-task.
/// Card stays on screen until the user clicks anywhere to dismiss.
struct PostBlackoutView: View {

    @ObservedObject var state: BlackoutPhaseState

    /// Opacity for awareness check fade-in
    @State private var checkOpacity: Double = 0
    /// Opacity for card content fade-in
    @State private var cardOpacity: Double = 0
    /// Awareness slider value (0–100, default at center)
    @State private var sliderValue: Double = 50

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state.phase {
            case .breathing:
                EmptyView()

            case .awarenessCheck:
                VStack(spacing: 28) {
                    Text(String(localized: "Were you there?"))
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.85))

                    VStack(spacing: 8) {
                        HStack {
                            Text(String(localized: "No"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(String(localized: "Yes"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(width: 280)

                        Slider(value: $sliderValue, in: 0...100, step: 1) { editing in
                            if !editing {
                                // Save on release
                                let score = Int(sliderValue)
                                ProgressTracker.shared.recordAwarenessScore(score)
                                state.awarenessScore = score
                                state.onAwarenessAnswered?()
                            }
                        }
                        .frame(width: 280)
                        .tint(.white.opacity(0.6))
                    }
                }
                .opacity(checkOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.4)) {
                        checkOpacity = 1.0
                    }
                }

            case .practiceCard:
                if showCardPhoto, let card = state.practiceCard {
                    // Card-photo mode: show the user's physical-card photo instead of the
                    // text phrase. Front first; tap flips to back; X (top-left) closes.
                    CardFlipView(cardID: card.id, accent: card.color) {
                        state.onDismissRequest?()
                    }
                    .opacity(cardOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.5)) { cardOpacity = 1.0 }
                    }
                } else {
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // In card-photo mode the flip view handles its own taps (flip + close).
            if state.phase == .practiceCard && !showCardPhoto {
                state.onDismissRequest?()
            }
        }
    }

    /// True when the day's card has a front photo to show at the break end —
    /// independent of the breathing visual mode.
    private var showCardPhoto: Bool {
        guard let card = state.practiceCard else { return false }
        return SettingsManager.shared.hasCardPhoto(cardID: card.id, side: .front)
    }
}

// MARK: - Card Flip View

/// Full-screen flip card showing a practice card's user-supplied photo.
/// Front shows first; tapping flips to the back (and back again) with a page-turn 3D
/// effect; a small ✕ in the top-left corner closes and returns to the normal screen.
struct CardFlipView: View {

    let cardID: String
    let accent: Color
    let onClose: () -> Void

    @State private var showingBack = false

    private var frontImage: NSImage? { loadImage(side: .front) }
    private var backImage: NSImage? { loadImage(side: .back) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            // Flip card — front and pre-rotated back stacked, container rotates on tap.
            // Edge-to-edge, aspect-fit (no crop): fills the screen as much as possible.
            ZStack {
                cardFace(frontImage, placeholder: "")
                    .opacity(showingBack ? 0 : 1)
                cardFace(backImage, placeholder: String(localized: "No back photo"))
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(showingBack ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotation3DEffect(.degrees(showingBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.55), value: showingBack)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                // Flip only when a back photo exists; otherwise stay on the front.
                if backImage != nil { showingBack.toggle() }
            }

            // Close button (top-left) — returns to the normal screen.
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    @ViewBuilder
    private func cardFace(_ image: NSImage?, placeholder: String) -> some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text(placeholder)
                .foregroundColor(.white.opacity(0.4))
                .font(.title3)
        }
    }

    private func loadImage(side: CardPhotoSide) -> NSImage? {
        guard SettingsManager.shared.hasCardPhoto(cardID: cardID, side: side) else { return nil }
        return NSImage(contentsOf: SettingsManager.shared.cardPhotoURL(cardID: cardID, side: side))
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
