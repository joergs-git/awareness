import SwiftUI

struct ContentView: View {
    @State private var playingItemId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - Start Sounds
                sectionHeader("Start Sounds", subtitle: "Calming, inviting")

                ForEach(SoundPresets.startSounds) { preset in
                    soundRow(preset: preset)
                }

                Divider()

                // MARK: - End Sounds
                sectionHeader("End Sounds", subtitle: "Awakening, return signal")

                ForEach(SoundPresets.endSounds) { preset in
                    soundRow(preset: preset)
                }

                Divider()

                // MARK: - Start Haptics
                sectionHeader("Start Haptics", subtitle: "Gentle, calming")

                ForEach(HapticPresets.startPatterns) { preset in
                    hapticRow(preset: preset)
                }

                Divider()

                // MARK: - End Haptics
                sectionHeader("End Haptics", subtitle: "Wake-up signal")

                ForEach(HapticPresets.endPatterns) { preset in
                    hapticRow(preset: preset)
                }

                // Note about haptics
                Text("Haptics only work on a real Apple Watch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sound Tester")
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sound Row

    private func soundRow(preset: SoundPreset) -> some View {
        let isPlaying = playingItemId == preset.id

        return Button {
            if isPlaying {
                ToneGenerator.shared.stop()
                playingItemId = nil
            } else {
                // Stop any previous playback
                ToneGenerator.shared.stop()
                HapticPlayer.shared.stop()

                playingItemId = preset.id
                ToneGenerator.shared.play(preset) {
                    // Clear highlight when playback finishes
                    if playingItemId == preset.id {
                        playingItemId = nil
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.caption)
                        .fontWeight(isPlaying ? .bold : .regular)
                    Text(preset.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(isPlaying ? .red : .green)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Haptic Row

    private func hapticRow(preset: HapticPreset) -> some View {
        let isPlaying = playingItemId == preset.id

        return Button {
            if isPlaying {
                HapticPlayer.shared.stop()
                playingItemId = nil
            } else {
                // Stop any previous playback
                ToneGenerator.shared.stop()
                HapticPlayer.shared.stop()

                playingItemId = preset.id
                HapticPlayer.shared.play(preset)

                // Auto-clear after estimated duration
                let totalDuration = preset.events.reduce(0.0) { $0 + $1.delayBefore } + 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
                    if playingItemId == preset.id {
                        playingItemId = nil
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.caption)
                        .fontWeight(isPlaying ? .bold : .regular)
                    Text(preset.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(isPlaying ? .red : .orange)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
