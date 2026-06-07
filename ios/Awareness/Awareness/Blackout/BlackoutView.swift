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
    /// Whether to show the card-photo flip (card-photo mode) after the awareness check
    @State private var showingCardPhoto = false
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
    /// Pre-formatted ISO 8601 string for the start time — reused for end event to guarantee upsert match
    @State private var syncFormattedStartDate: String?
    /// Cached data for deferred MindfulEvent creation (completed blackouts wait for awareness score)
    @State private var pendingEventInterval: Double?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Breathing content — hidden once the awareness check or card photo appears
            if !showingAwarenessCheck && !showingCardPhoto {
                switch settings.visualType {
                case .plainBlack, .cardPhoto:
                    // Minimal anchor while breathing; card photo is shown at the break end.
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

            // Card-photo flip — shown at the break end instead of a phrase (card-photo mode)
            if showingCardPhoto, let card = todaysCard {
                CardFlipView(cardID: card.id, accent: card.color) {
                    closeBlackout()
                }
                .transition(.opacity)
            }
        }
        .opacity(opacity)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
            // Don't dismiss during awareness check or card photo — they handle their own taps
            guard !showingAwarenessCheck, !showingCardPhoto else { return }
            // Tap to dismiss early (disabled in handcuffs mode)
            guard !settings.handcuffsMode else { return }
            dismissBlackout()
        }
        .onAppear {
            // Prevent auto-lock while the blackout is showing
            UIApplication.shared.isIdleTimerDisabled = true

            sessionStart = Date()
            syncEventStartTime = sessionStart
            // Format the start date ONCE and reuse for all upserts to guarantee matching started_at
            syncFormattedStartDate = SupabaseClient.formatDate(sessionStart!)
            // Resolve breathing text once (random rotation for default, custom text otherwise)
            displayText = settings.resolvedBreathingText()
            // Use guru-adapted duration when Smart Guru is enabled
            duration = settings.effectiveRandomBlackoutDuration()
            offeredDuration = duration
            GongPlayer.shared.playStartIfEnabled()

            // Upload sync event at START so other platforms know a break is in progress
            if let formattedDate = syncFormattedStartDate {
                SyncManager.shared.recordEventRaw(
                    startedAt: formattedDate,
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

        // Record actual elapsed duration for the trend chart
        if let start = sessionStart {
            ProgressTracker.shared.recordSessionDuration(Date().timeIntervalSince(start))
        }

        // Record completion only if the blackout ran its full duration
        if completedFullDuration {
            ProgressTracker.shared.recordCompleted()
        }

        // Record event for Smart Guru analysis.
        // For completed blackouts, defer to handleAwarenessScore() so the awareness score
        // is captured in the MindfulEvent. For early dismissals, record immediately.
        let intervalFromPrev = EventStore.shared.lastEventTimestamp
            .map { Date().timeIntervalSince1970 - $0 }
        pendingEventInterval = intervalFromPrev

        if !completedFullDuration {
            let actualDuration = sessionStart.map { Date().timeIntervalSince($0) }
            let event = MindfulEvent.create(
                outcome: .dismissed,
                durationOffered: offeredDuration,
                durationActual: actualDuration,
                intervalFromPrevious: intervalFromPrev,
                awarenessScore: nil
            )
            EventStore.shared.record(event: event)
            SmartGuru.shared.evaluateAfterEvent(event)
        }

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

        // Upload completed=true immediately (before awareness check) as fallback.
        // The awareness score will upsert on top of this when the user submits.
        if completedFullDuration {
            uploadSyncEvent(completed: true, awareness: nil)
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
                // Log dismissed event to local event store
                if let start = syncEventStartTime {
                    LocalEventLog.shared.recordFromBlackout(
                        startedAt: start,
                        duration: Date().timeIntervalSince(start),
                        completed: false,
                        awarenessScore: nil,
                        source: "ios"
                    )
                }
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

    /// Record awareness score, log event, run Smart Guru evaluation, and dismiss
    private func handleAwarenessScore(_ score: Int) {
        ProgressTracker.shared.recordAwarenessScore(score)
        // Upload final sync event with awareness score
        uploadSyncEvent(completed: true, awareness: "\(score)")
        // Log to local event store for cross-platform analytics
        if let start = syncEventStartTime {
            LocalEventLog.shared.recordFromBlackout(
                startedAt: start,
                duration: Date().timeIntervalSince(start),
                completed: completedFullDuration,
                awarenessScore: score,
                source: "ios"
            )
        }

        // Create deferred MindfulEvent with awareness score for Smart Guru
        let actualDuration = sessionStart.map { Date().timeIntervalSince($0) }
        let event = MindfulEvent.create(
            outcome: .completed,
            durationOffered: offeredDuration,
            durationActual: actualDuration,
            intervalFromPrevious: pendingEventInterval,
            awarenessScore: score
        )
        EventStore.shared.record(event: event)
        SmartGuru.shared.evaluateAfterEvent(event)

        // Card-photo mode: after the awareness check, reveal the card photo (front, tap to
        // flip, ✕ to close) instead of dismissing straight away.
        if shouldShowCardPhoto {
            withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingAwarenessCheck = false
                showingCardPhoto = true
                withAnimation(.easeIn(duration: 0.3)) { opacity = 1.0 }
            }
        } else {
            closeBlackout()
        }
    }

    /// Today's practice card (cached per day by SettingsManager).
    private var todaysCard: PracticeCard? { settings.todaysPracticeCard() }

    /// True when today's card has a front photo to show at the break end.
    /// Independent of the breathing visual mode — if you gave the day's card a photo,
    /// you see it (front, tap to flip, ✕ to close) instead of just dismissing.
    private var shouldShowCardPhoto: Bool {
        guard let card = todaysCard else { return false }
        return settings.hasCardPhoto(cardID: card.id, side: .front)
    }

    /// Fade out and dismiss the blackout.
    private func closeBlackout() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIApplication.shared.isIdleTimerDisabled = false
            isPresented = false
        }
    }

    // MARK: - Sync Upload

    /// Upload the current blackout state to Supabase (upserts on sync_key + started_at + source).
    /// Uses the pre-formatted start date to guarantee the upsert matches the start event.
    private func uploadSyncEvent(completed: Bool, awareness: String?) {
        guard let formattedDate = syncFormattedStartDate,
              let start = syncEventStartTime else { return }
        let actualDuration = Date().timeIntervalSince(start)
        SyncManager.shared.recordEventRaw(
            startedAt: formattedDate,
            duration: actualDuration,
            completed: completed,
            awareness: awareness
        )
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

// MARK: - Card Flip View

/// Full-screen flip card showing a practice card's user-supplied photo.
/// Front shows first; tapping flips to the back (and back again) with a page-turn 3D
/// effect; a small ✕ in the top-left corner closes and returns to the normal screen.
struct CardFlipView: View {

    let cardID: String
    let accent: Color
    let onClose: () -> Void

    @State private var showingBack = false

    private var frontImage: UIImage? { loadImage(side: .front) }
    private var backImage: UIImage? { loadImage(side: .back) }

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
            .padding(20)
        }
    }

    @ViewBuilder
    private func cardFace(_ image: UIImage?, placeholder: String) -> some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text(placeholder)
                .foregroundColor(.white.opacity(0.4))
                .font(.title3)
        }
    }

    private func loadImage(side: CardPhotoSide) -> UIImage? {
        guard SettingsManager.shared.hasCardPhoto(cardID: cardID, side: side),
              let data = try? Data(contentsOf: SettingsManager.shared.cardPhotoURL(cardID: cardID, side: side)) else {
            return nil
        }
        return UIImage(data: data)
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
