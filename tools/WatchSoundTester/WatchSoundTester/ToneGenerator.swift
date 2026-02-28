import AVFoundation
import Foundation

/// Real-time audio synthesis engine using AVAudioEngine + AVAudioSourceNode.
/// Generates tones from parameters — no pre-rendered audio files needed.
class ToneGenerator {
    static let shared = ToneGenerator()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    /// Current playback state — read from the render thread
    private var isPlaying = false

    /// The sequence of tone segments to render (set before starting)
    private var segments: [ToneSegment] = []

    /// Index of the currently rendering segment
    private var currentSegmentIndex = 0

    /// Sample position within the current segment
    private var sampleIndex: UInt64 = 0

    /// Audio sample rate (typically 44100 or 48000)
    private let sampleRate: Double = 44100.0

    /// Phase accumulator for continuous waveform generation
    private var phase: Double = 0.0

    /// Completion callback fired when all segments finish
    private var completionHandler: (() -> Void)?

    private init() {}

    // MARK: - Public API

    /// Play a sound preset consisting of one or more tone segments.
    /// Each segment plays sequentially with optional gaps between them.
    func play(_ preset: SoundPreset, completion: (() -> Void)? = nil) {
        stop()

        segments = preset.segments
        currentSegmentIndex = 0
        sampleIndex = 0
        phase = 0.0
        completionHandler = completion

        configureAudioSession()
        setupEngine()

        isPlaying = true

        do {
            try engine.start()
        } catch {
            print("ToneGenerator: failed to start engine — \(error)")
            isPlaying = false
        }
    }

    /// Stop any currently playing sound immediately.
    func stop() {
        isPlaying = false

        if engine.isRunning {
            engine.stop()
        }

        // Remove old source node if it exists
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }

        completionHandler = nil
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("ToneGenerator: audio session configuration failed — \(error)")
        }
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        // Remove previous source node
        if let node = sourceNode {
            engine.detach(node)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Capture self weakly for the render block
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

                // Check if we've finished all segments
                guard self.currentSegmentIndex < self.segments.count else {
                    ptr[frame] = 0.0
                    if self.isPlaying {
                        self.isPlaying = false
                        // Fire completion on main thread
                        DispatchQueue.main.async { [weak self] in
                            self?.completionHandler?()
                            self?.completionHandler = nil
                        }
                    }
                    continue
                }

                let segment = self.segments[self.currentSegmentIndex]
                let totalSamples = UInt64(segment.totalDuration * self.sampleRate)

                if self.sampleIndex >= totalSamples {
                    // Move to next segment
                    self.currentSegmentIndex += 1
                    self.sampleIndex = 0
                    self.phase = 0.0
                    ptr[frame] = 0.0
                    continue
                }

                let sample = self.renderSample(segment: segment)
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

    /// Render a single audio sample for the given tone segment.
    private func renderSample(segment: ToneSegment) -> Double {
        let time = Double(sampleIndex) / sampleRate

        // Silence gap before the tone starts
        if time < segment.delayBefore {
            return 0.0
        }

        let toneTime = time - segment.delayBefore
        let toneDuration = segment.toneDuration

        // Past the tone portion — silence until segment ends
        if toneTime >= toneDuration {
            return 0.0
        }

        // Calculate frequency (supports sweeps)
        let freq: Double
        if let endFreq = segment.endFrequency {
            // Linear frequency sweep
            let progress = toneTime / toneDuration
            freq = segment.frequency + (endFreq - segment.frequency) * progress
        } else {
            freq = segment.frequency
        }

        // Generate waveform with harmonics
        var sample = 0.0

        // Fundamental
        phase += 2.0 * .pi * freq / sampleRate
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }
        sample += sin(phase)

        // Overtones (additive synthesis)
        for harmonic in segment.harmonics {
            let harmonicPhase = phase * harmonic.multiplier
            sample += sin(harmonicPhase) * harmonic.amplitude
        }

        // Normalize based on harmonic count
        let totalAmplitude = 1.0 + segment.harmonics.reduce(0.0) { $0 + $1.amplitude }
        sample /= totalAmplitude

        // Apply envelope (attack + decay)
        let envelope = calculateEnvelope(
            time: toneTime,
            duration: toneDuration,
            attack: segment.attackTime,
            decay: segment.decayTime
        )

        return sample * envelope * segment.volume
    }

    /// Calculate an amplitude envelope with linear attack and exponential decay.
    private func calculateEnvelope(time: Double, duration: Double, attack: Double, decay: Double) -> Double {
        // Attack phase — linear ramp up
        if time < attack {
            return time / attack
        }

        // Decay phase — exponential falloff
        let decayStart = attack
        let timeSinceDecay = time - decayStart
        let decayDuration = duration - attack

        if decayDuration <= 0 { return 1.0 }

        // Exponential decay: e^(-t * rate)
        // The decay parameter controls how quickly the sound fades
        // Higher decay = faster fade
        let decayRate = decay / decayDuration
        return exp(-timeSinceDecay * decayRate * 5.0)
    }
}

// MARK: - Data Models

/// A single tone segment — one continuous sound with optional delay before it.
struct ToneSegment {
    /// Fundamental frequency in Hz
    let frequency: Double

    /// Optional end frequency for sweep effects (nil = constant pitch)
    let endFrequency: Double?

    /// Overtone harmonics added to the fundamental
    let harmonics: [Harmonic]

    /// Duration of the audible tone in seconds
    let toneDuration: Double

    /// Silent gap before this segment starts (used for multi-tone presets)
    let delayBefore: Double

    /// Attack time — how quickly the tone ramps up (seconds)
    let attackTime: Double

    /// Decay factor — controls exponential falloff speed (higher = faster decay)
    let decayTime: Double

    /// Overall volume (0.0–1.0)
    let volume: Double

    /// Total duration including delay + tone
    var totalDuration: Double {
        delayBefore + toneDuration
    }

    init(
        frequency: Double,
        endFrequency: Double? = nil,
        harmonics: [Harmonic] = [],
        toneDuration: Double,
        delayBefore: Double = 0.0,
        attackTime: Double = 0.01,
        decayTime: Double = 1.0,
        volume: Double = 0.6
    ) {
        self.frequency = frequency
        self.endFrequency = endFrequency
        self.harmonics = harmonics
        self.toneDuration = toneDuration
        self.delayBefore = delayBefore
        self.attackTime = attackTime
        self.decayTime = decayTime
        self.volume = volume
    }
}

/// An overtone harmonic — frequency multiplier relative to the fundamental.
struct Harmonic {
    /// Frequency multiplier (e.g. 2.0 = octave, 3.0 = fifth above octave)
    let multiplier: Double

    /// Relative amplitude (0.0–1.0)
    let amplitude: Double
}
