import SwiftUI

/// Volume-slider-style awareness check for watchOS.
/// Displays a fillable horizontal bar that responds to finger touch and Digital Crown rotation.
/// Auto-saves after 2 seconds of inactivity — no Done button needed.
struct WatchAwarenessBar: View {

    @Binding var value: Double
    let onSubmit: (Int) -> Void

    /// Tracks Digital Crown rotation delta
    @State private var crownDelta: Double = 0
    /// Debounce timer — auto-submits 2s after last interaction
    @State private var debounceTimer: Timer?
    /// Whether the crown is currently being rotated (focus state)
    @State private var isCrownActive: Bool = false
    /// Whether the initial grace period has elapsed (prevents premature auto-dismiss)
    @State private var graceElapsed: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Text(String(localized: "Were you there?"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.85))

            // Current value display
            Text("\(Int(value))")
                .font(.system(size: 28, weight: .medium).monospacedDigit())
                .foregroundColor(.white)

            // Fillable bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.6))
                        .frame(width: max(0, geometry.size.width * value / 100.0))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = (gesture.location.x / geometry.size.width) * 100
                            value = max(0, min(100, newValue))
                            resetDebounceTimer()
                        }
                )
            }
            .frame(height: 20)

            // No/Yes labels
            HStack {
                Text(String(localized: "No"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(String(localized: "Yes"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .focusable(true)
        .digitalCrownRotation(
            $crownDelta,
            from: -50,
            through: 50,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownDelta, perform: { newDelta in
            // Crown rotation adjusts value — each full step ~= 2 points
            let newValue = value + newDelta
            value = max(0, min(100, newValue))
            crownDelta = 0
            resetDebounceTimer()
        })
        .onAppear {
            // 2s grace period so the slider doesn't vanish before the user can react
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                graceElapsed = true
                resetDebounceTimer()
            }
        }
        .onDisappear {
            debounceTimer?.invalidate()
            debounceTimer = nil
        }
    }

    /// Reset the 2-second debounce timer. When it fires, the score is auto-submitted.
    /// During the initial 2s grace period, only user interactions (drag/crown) trigger
    /// the debounce — the timer won't start on its own until the grace period elapses.
    private func resetDebounceTimer() {
        guard graceElapsed else { return }
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            onSubmit(Int(value))
        }
    }
}
