import AVFoundation
import Foundation

/// Plays bundled gong sounds for blackout start and end.
/// The start gong is higher pitched, the end gong is deeper to signal "time's up".
/// Each gong has its own enable/disable setting.
class GongPlayer {

    static let shared = GongPlayer()

    // Separate players so start and end sounds can overlap if needed
    private var startPlayer: AVAudioPlayer?
    private var endPlayer: AVAudioPlayer?

    private init() {}

    /// Play the start gong if the start gong setting is enabled
    func playStartIfEnabled() {
        guard SettingsManager.shared.startGongEnabled else { return }
        playStart()
    }

    /// Play the end gong if the end gong setting is enabled
    func playEndIfEnabled() {
        guard SettingsManager.shared.endGongEnabled else { return }
        playEnd()
    }

    /// Play the higher-pitched start gong
    func playStart() {
        guard let url = Bundle.main.url(forResource: "awareness-gong", withExtension: "aiff") else {
            print("Awareness: start gong sound not found in bundle")
            return
        }
        startPlayer = playSound(at: url)
    }

    /// Play the deeper-pitched end gong
    func playEnd() {
        guard let url = Bundle.main.url(forResource: "awareness-gong-end", withExtension: "aiff") else {
            print("Awareness: end gong sound not found in bundle")
            return
        }
        endPlayer = playSound(at: url)
    }

    private func playSound(at url: URL) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            return player
        } catch {
            print("Awareness: failed to play sound — \(error.localizedDescription)")
            return nil
        }
    }
}
