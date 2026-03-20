import SwiftUI

/// First-launch onboarding screen shown once to introduce the app concept.
/// Displays a minimal, warm-toned full-screen view with the yin-yang symbol and a brief instruction.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Warm background gradient (matches WarmBackground)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.14, green: 0.10, blue: 0.20),
                       Color(red: 0.09, green: 0.07, blue: 0.14)]
                    : [Color(red: 0.94, green: 0.91, blue: 0.98),
                       Color(red: 0.88, green: 0.84, blue: 0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Yin-yang symbol
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .grayscale(1.0)
                    .opacity(0.7)

                // Instruction text
                Text(String(localized: "Tap the symbol — Close your eyes.\nBreathe.\nOpen your eyes.\n\nThis is your first Atempause."))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.horizontal, 40)

                Spacer()

                // Dismiss button
                Button(action: {
                    SettingsManager.shared.hasLaunchedBefore = true
                    dismiss()
                }) {
                    Text(String(localized: "Start"))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.55, green: 0.38, blue: 0.72))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}
