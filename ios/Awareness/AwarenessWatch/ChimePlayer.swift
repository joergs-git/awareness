import AVFoundation

/// Synthesizes a double chime (440Hz → 660Hz) for the blackout start signal on Apple Watch.
/// Uses AVAudioEngine + AVAudioSourceNode for real-time tone generation — no audio files needed.
/// Audio session is set to `.ambient` so the chime respects watchOS silent/mute mode.
final class ChimePlayer {

    static let shared = ChimePlayer()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    /// Current playback state — read from the render thread
    private var isPlaying = false

    /// Index of the currently rendering tone segment
    private var currentSegmentIndex = 0

    /// Sample position within the current segment
    private var sampleIndex: UInt64 = 0

    /// Phase accumulator for continuous sine wave generation
    private var phase: Double = 0.0

    private let sampleRate: Double = 44100.0

    // MARK: - Double Chime Definition

    /// The two-tone chime: 440Hz (0.3s) then 660Hz (0.4s) with a short gap.
    /// Matches the "Double Chime" preset tested via WatchSoundTester.
    private struct Tone {
        let frequency: Double
        let toneDuration: Double
        let delayBefore: Double
        let attackTime: Double
        let decayTime: Double
        let volume: Double

        var totalDuration: Double { delayBefore + toneDuration }
    }

    /// Start chime tones — played at the beginning of a blackout
    private let chimeTones: [Tone] = [
        Tone(frequency: 440.0, toneDuration: 0.3, delayBefore: 0.0,
             attackTime: 0.005, decayTime: 1.5, volume: 0.5),
        Tone(frequency: 660.0, toneDuration: 0.4, delayBefore: 0.15,
             attackTime: 0.005, decayTime: 1.2, volume: 0.5)
    ]

    /// The active tone sequence — either chime tones or chime + keep-alive
    private var tones: [Tone] = []

    private init() {}

    // MARK: - Public API

    /// Play the double chime start signal (440Hz → 660Hz).
    /// Respects watchOS silent mode via `.ambient` audio session category.
    func playStartChime() {
        stop()

        tones = chimeTones
        currentSegmentIndex = 0
        sampleIndex = 0
        phase = 0.0

        configureAudioSession()
        setupEngine()

        isPlaying = true

        do {
            try engine.start()
        } catch {
            print("ChimePlayer: failed to start engine — \(error)")
            isPlaying = false
        }
    }

    /// Play the start chime followed by a near-silent sustained tone for the blackout duration.
    /// Keeping the AVAudioEngine active signals to watchOS that the app has an active audio
    /// session, which gives the process better scheduling priority and helps prevent aggressive
    /// timer throttling when the display dims.
    func playStartChimeWithKeepAlive(duration: TimeInterval) {
        stop()

        // Chime tones total ~0.85s. The keep-alive starts after, filling the remaining duration.
        let chimeDuration = chimeTones.reduce(0.0) { $0 + $1.totalDuration }
        let keepAliveDuration = max(1.0, duration - chimeDuration)

        // Build tone sequence: start chime + near-silent keep-alive tone
        tones = chimeTones + [
            Tone(frequency: 1.0, toneDuration: keepAliveDuration, delayBefore: 0.0,
                 attackTime: 0.01, decayTime: 0.0, volume: 0.001)
        ]

        currentSegmentIndex = 0
        sampleIndex = 0
        phase = 0.0

        configureAudioSession()
        setupEngine()

        isPlaying = true

        do {
            try engine.start()
        } catch {
            print("ChimePlayer: failed to start engine — \(error)")
            isPlaying = false
        }
    }

    /// Stop playback and clean up the audio engine.
    func stop() {
        isPlaying = false

        if engine.isRunning {
            engine.stop()
        }

        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .ambient respects the system mute/silent switch
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            print("ChimePlayer: audio session configuration failed — \(error)")
        }
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        if let node = sourceNode {
            engine.detach(node)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                if !self.isPlaying {
                    ptr[frame] = 0.0
                    continue
                }

                // All segments finished — stop playback
                guard self.currentSegmentIndex < self.tones.count else {
                    ptr[frame] = 0.0
                    if self.isPlaying {
                        self.isPlaying = false
                        DispatchQueue.main.async { [weak self] in
                            self?.stop()
                        }
                    }
                    continue
                }

                let tone = self.tones[self.currentSegmentIndex]
                let totalSamples = UInt64(tone.totalDuration * self.sampleRate)

                // Advance to next segment when current one finishes
                if self.sampleIndex >= totalSamples {
                    self.currentSegmentIndex += 1
                    self.sampleIndex = 0
                    self.phase = 0.0
                    ptr[frame] = 0.0
                    continue
                }

                let sample = self.renderSample(tone: tone)
                ptr[frame] = Float(sample)
                self.sampleIndex += 1
            }

            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    // MARK: - Sample Rendering

    /// Render a single audio sample for the given tone.
    private func renderSample(tone: Tone) -> Double {
        let time = Double(sampleIndex) / sampleRate

        // Silent gap before the tone
        if time < tone.delayBefore {
            return 0.0
        }

        let toneTime = time - tone.delayBefore

        // Past the tone portion — silence
        if toneTime >= tone.toneDuration {
            return 0.0
        }

        // Generate pure sine wave at the tone's frequency
        phase += 2.0 * .pi * tone.frequency / sampleRate
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }
        let sample = sin(phase)

        // Apply envelope (linear attack + exponential decay)
        let envelope = calculateEnvelope(
            time: toneTime,
            duration: tone.toneDuration,
            attack: tone.attackTime,
            decay: tone.decayTime
        )

        return sample * envelope * tone.volume
    }

    /// Linear attack ramp followed by exponential decay falloff.
    private func calculateEnvelope(time: Double, duration: Double, attack: Double, decay: Double) -> Double {
        // Attack phase — linear ramp up
        if time < attack {
            return time / attack
        }

        // Decay phase — exponential falloff
        let timeSinceDecay = time - attack
        let decayDuration = duration - attack
        guard decayDuration > 0 else { return 1.0 }

        let decayRate = decay / decayDuration
        return exp(-timeSinceDecay * decayRate * 5.0)
    }
}
