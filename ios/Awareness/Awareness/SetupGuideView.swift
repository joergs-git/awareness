import SwiftUI

/// Detailed setup guide shown after the user's 3rd completed breath.
/// Teaches device optimization for a focused mindfulness practice.
/// Reopenable from the main menu at any time.
/// Includes cropped screenshots with tap-to-expand navigation paths.
struct SetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Which guide item's image is expanded (nil = none)
    @State private var expandedItem: String?
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    /// Warm earthy accent color matching the app's palette
    private let accent = Color(red: 0.72, green: 0.50, blue: 0.38)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.14, green: 0.12, blue: 0.11),
                       Color(red: 0.10, green: 0.09, blue: 0.08)]
                    : [Color(red: 0.98, green: 0.92, blue: 0.84),
                       Color(red: 0.93, green: 0.85, blue: 0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .grayscale(1.0)
                            .opacity(0.7)

                        Text(String(localized: "Optimize Your Practice"))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(String(localized: "A few simple changes to your device will make a big difference."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    // MARK: - Home Screen Widget
                    guideCard(
                        id: "widget",
                        icon: "rectangle.on.rectangle",
                        title: String(localized: "Add a Home Screen Widget"),
                        body: String(localized: "Long-press your home screen → tap + → search \"Atempause\" → add the widget. See your next break at a glance."),
                        imageName: "GuideWidget",
                        steps: [
                            String(localized: "Long-press on your home screen"),
                            String(localized: "Tap \"Edit\" → \"Add Widget\""),
                            String(localized: "Search for \"Atempause\""),
                            String(localized: "Choose small or medium size"),
                            String(localized: "Tap \"Add Widget\"")
                        ]
                    )

                    // MARK: - Lock Screen Widget
                    guideCard(
                        id: "lockscreen",
                        icon: "lock.rectangle.on.rectangle",
                        title: String(localized: "Add a Lock Screen Widget"),
                        body: String(localized: "Long-press your lock screen → Customize → add an Atempause widget. Every glance becomes a reminder to breathe."),
                        imageName: "GuideLockScreen",
                        steps: [
                            String(localized: "Long-press on your lock screen"),
                            String(localized: "Tap \"Customize\""),
                            String(localized: "Select the lock screen"),
                            String(localized: "Tap the widget area below the clock"),
                            String(localized: "Search and add \"Atempause\"")
                        ]
                    )

                    // MARK: - Apple Watch (only shown when a watch is paired)
                    if watchManager.isPaired {
                    guideCard(
                        id: "watch",
                        icon: "applewatch",
                        title: String(localized: "Apple Watch Complications"),
                        body: String(localized: "On your watch, long-press the face → Edit → add two Atempause complications: a small one for your streak and a larger one for quick access. Create a dedicated mindfulness watch face layout."),
                        imageName: "GuideWatch",
                        steps: [
                            String(localized: "Long-press on your watch face"),
                            String(localized: "Tap \"Edit\""),
                            String(localized: "Swipe to the complications page"),
                            String(localized: "Tap a slot → choose \"Atempause\""),
                            String(localized: "Add a second complication in another slot"),
                            String(localized: "Tip: Create a new \"Simple\" watch face just for practice")
                        ]
                    )
                    }

                    // MARK: - Silence Notifications
                    guideCard(
                        id: "silence",
                        icon: "bell.slash",
                        title: String(localized: "Silence Distractions"),
                        body: String(localized: "Go to Settings → Notifications and turn off alerts from messengers (WhatsApp, Instagram, Slack, X, ...). They constantly pull you out of presence. Keep only truly important ones."),
                        imageName: "GuideNotifications",
                        steps: [
                            String(localized: "Open ⚙️ Settings"),
                            String(localized: "Tap \"Notifications\""),
                            String(localized: "Find WhatsApp, Instagram, Slack, etc."),
                            String(localized: "Turn off \"Allow Notifications\""),
                            String(localized: "Keep only Phone, Messages, Calendar")
                        ]
                    )

                    // MARK: - Enable Atempause Notifications
                    guideCard(
                        id: "enable",
                        icon: "bell.badge",
                        title: String(localized: "Enable Atempause Notifications"),
                        body: String(localized: "Make sure Atempause notifications are enabled so you receive gentle reminders even when the app is in the background."),
                        imageName: "GuideNotifications",
                        steps: [
                            String(localized: "Open ⚙️ Settings"),
                            String(localized: "Tap \"Notifications\""),
                            String(localized: "Find \"Atempause\""),
                            String(localized: "Enable \"Allow Notifications\""),
                            String(localized: "Choose \"Time Sensitive Delivery\" if available")
                        ]
                    )

                    // MARK: - Clean Home Screen
                    guideCard(
                        id: "clean",
                        icon: "square.grid.2x2",
                        title: String(localized: "Clean Your Home Screen"),
                        body: String(localized: "Move distracting apps to a second page or the App Library. Your first screen should only show what truly matters. Everything else: out of sight, out of mind."),
                        imageName: "GuideHomeScreen",
                        steps: [
                            String(localized: "Long-press on your home screen"),
                            String(localized: "Drag distracting apps to the right (second page)"),
                            String(localized: "Or drag them down to remove from home screen"),
                            String(localized: "Keep only: Phone, Messages, Calendar, Atempause"),
                            String(localized: "Add the Atempause widget for a mindful first screen")
                        ]
                    )

                    // MARK: - Fresh Notification Sounds
                    guideCard(
                        id: "sounds",
                        icon: "speaker.wave.2",
                        title: String(localized: "Refresh Your Notification Sounds"),
                        body: String(localized: "You've probably become deaf to your current tones — your brain filters them out. Change them now so you actually notice when something matters."),
                        imageName: "GuideWatch",
                        steps: [
                            String(localized: "On Apple Watch: Settings → Sounds & Haptics"),
                            String(localized: "Try \"Resonance\", \"Timer\", or \"Stunner\" as new tones"),
                            String(localized: "On iPhone: Settings → Sounds & Haptics"),
                            String(localized: "Change text tone and notification sound"),
                            String(localized: "Pick something you haven't used before")
                        ]
                    )

                    // MARK: - Why This Matters
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(accent)
                            Text(String(localized: "Why This Matters"))
                                .font(.headline)
                        }

                        Text(String(localized: "Every notification, every app icon, every badge competes for your attention. Your phone is designed to grab it. Simplifying your device is not just a nice-to-have — it's the foundation for your practice. The less noise, the more presence."))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // Hide from main screen toggle
                    Toggle(isOn: $settings.setupGuideHidden) {
                        Text(String(localized: "Hide from main screen"))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .tint(accent)
                    .padding(.horizontal, 4)

                    // Dismiss
                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "Got it"))
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accent)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // Track open count — auto-hide after 2nd opening
            settings.setupGuideOpenCount += 1
            if settings.setupGuideOpenCount >= 2 {
                settings.setupGuideHidden = true
            }
        }
    }

    // MARK: - Guide Card with Image + Steps

    @ViewBuilder
    private func guideCard(
        id: String,
        icon: String,
        title: String,
        body: String,
        imageName: String,
        steps: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(accent)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
            }

            // Description
            Text(body)
                .font(.callout)
                .foregroundColor(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            // Thumbnail image — tap to expand with step-by-step path
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedItem = expandedItem == id ? nil : id
                }
            } label: {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: expandedItem == id ? 200 : 80)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if expandedItem != id {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.4)))
                                .padding(6)
                        }
                    }
            }
            .buttonStyle(.plain)

            // Step-by-step navigation path (shown when expanded)
            if expandedItem == id {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(accent)
                                .frame(width: 18, alignment: .trailing)
                            Text(step)
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.08))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
    }
}
