import SwiftUI

/// Setup guide for macOS users who also have an iPhone/Apple Watch.
/// Shows optimization tips for the iOS device, opened from the macOS Settings window.
struct SetupGuideView: View {

    private let accent = Color(red: 0.55, green: 0.38, blue: 0.72)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(spacing: 6) {
                    if #available(macOS 14.0, *) {
                        Image(systemName: "yinyang")
                            .font(.largeTitle)
                            .foregroundColor(accent)
                    } else {
                        Text("☯")
                            .font(.largeTitle)
                    }

                    Text(String(localized: "Optimize Your iPhone for Mindful Practice"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(String(localized: "A few changes on your iPhone make a big difference for your daily practice."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Divider()

                guideItem(
                    icon: "rectangle.on.rectangle",
                    title: String(localized: "Add Home Screen & Lock Screen Widgets"),
                    body: String(localized: "On your iPhone, long-press the home screen → Add Widget → search \"Atempause\". Do the same on your lock screen. Every glance becomes a reminder.")
                )

                guideItem(
                    icon: "applewatch",
                    title: String(localized: "Apple Watch Complications"),
                    body: String(localized: "Long-press your watch face → Edit → add two Atempause complications. Create a dedicated mindfulness watch face.")
                )

                guideItem(
                    icon: "bell.slash",
                    title: String(localized: "Silence Messenger Notifications"),
                    body: String(localized: "On your iPhone: Settings → Notifications → turn off WhatsApp, Instagram, Slack, X, etc. They pull you out of presence. Keep only the truly important ones.")
                )

                guideItem(
                    icon: "bell.badge",
                    title: String(localized: "Enable Atempause Notifications"),
                    body: String(localized: "Make sure Atempause notifications are enabled on your iPhone so you receive reminders even in the background.")
                )

                guideItem(
                    icon: "square.grid.2x2",
                    title: String(localized: "Clean Your iPhone Home Screen"),
                    body: String(localized: "Move distracting apps to a second page. Your first screen should only show what truly matters. Everything else: out of sight, out of mind.")
                )

                guideItem(
                    icon: "speaker.wave.2",
                    title: String(localized: "Refresh Your Notification Sounds"),
                    body: String(localized: "Change your notification tones on iPhone and Apple Watch — your brain has learned to ignore the current ones. On watchOS try \"Resonance\", \"Timer\", or \"Stunner\" under Sounds & Haptics.")
                )

                // Why section
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(accent)
                        Text(String(localized: "Why This Matters"))
                            .font(.headline)
                    }
                    Text(String(localized: "Every notification, every app icon competes for your attention. Simplifying your devices is not a nice-to-have — it's the foundation for your practice."))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
        }
        .background(WarmBackground())
        .frame(width: 440, height: 520)
    }

    @ViewBuilder
    private func guideItem(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(accent)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
            }
            Text(body)
                .font(.callout)
                .foregroundColor(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
