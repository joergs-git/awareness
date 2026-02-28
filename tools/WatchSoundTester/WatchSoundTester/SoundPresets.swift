import Foundation

/// A named sound preset consisting of one or more sequential tone segments.
struct SoundPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let segments: [ToneSegment]
}

/// Predefined sound presets for testing start and end signals.
enum SoundPresets {

    // MARK: - Start Sounds (calming, inviting — 0.5–2s)

    static let startSounds: [SoundPreset] = [
        tibetanBowl,
        softBell,
        windChime,
        gentlePing,
        deepTone
    ]

    /// Rich resonant bowl with overtones — long, meditative decay
    static let tibetanBowl = SoundPreset(
        name: "Tibetan Bowl",
        description: "220Hz + overtones, slow attack, long decay",
        segments: [
            ToneSegment(
                frequency: 220.0,
                harmonics: [
                    Harmonic(multiplier: 2.5, amplitude: 0.5),
                    Harmonic(multiplier: 3.8, amplitude: 0.3)
                ],
                toneDuration: 2.0,
                attackTime: 0.05,
                decayTime: 1.2,
                volume: 0.7
            )
        ]
    )

    /// Clean bell tone with light harmonics — medium length
    static let softBell = SoundPreset(
        name: "Soft Bell",
        description: "440Hz, quick attack, medium decay",
        segments: [
            ToneSegment(
                frequency: 440.0,
                harmonics: [
                    Harmonic(multiplier: 2.0, amplitude: 0.2),
                    Harmonic(multiplier: 3.0, amplitude: 0.1)
                ],
                toneDuration: 1.5,
                attackTime: 0.01,
                decayTime: 1.0,
                volume: 0.5
            )
        ]
    )

    /// High, delicate tone — brief and airy
    static let windChime = SoundPreset(
        name: "Wind Chime",
        description: "880Hz, very gentle, short, pure tone",
        segments: [
            ToneSegment(
                frequency: 880.0,
                toneDuration: 0.8,
                attackTime: 0.02,
                decayTime: 1.5,
                volume: 0.35
            )
        ]
    )

    /// Minimal soft ping — barely there
    static let gentlePing = SoundPreset(
        name: "Gentle Ping",
        description: "330Hz, very short (0.5s), soft sine",
        segments: [
            ToneSegment(
                frequency: 330.0,
                toneDuration: 0.5,
                attackTime: 0.005,
                decayTime: 1.8,
                volume: 0.4
            )
        ]
    )

    /// Low-frequency hum — grounding and warm
    static let deepTone = SoundPreset(
        name: "Deep Tone",
        description: "165Hz, medium duration, smooth sine",
        segments: [
            ToneSegment(
                frequency: 165.0,
                harmonics: [
                    Harmonic(multiplier: 2.0, amplitude: 0.15)
                ],
                toneDuration: 1.5,
                attackTime: 0.08,
                decayTime: 0.8,
                volume: 0.6
            )
        ]
    )

    // MARK: - End Sounds (awakening, signaling return — 0.3–1.5s)

    static let endSounds: [SoundPreset] = [
        risingSweep,
        doubleChime,
        brightBell,
        softGong,
        triplePing
    ]

    /// Pitch slides upward — energizing signal to return
    static let risingSweep = SoundPreset(
        name: "Rising Sweep",
        description: "220→440Hz linear sweep, 1s",
        segments: [
            ToneSegment(
                frequency: 220.0,
                endFrequency: 440.0,
                toneDuration: 1.0,
                attackTime: 0.02,
                decayTime: 0.6,
                volume: 0.5
            )
        ]
    )

    /// Two quick tones in succession — a polite "ding-ding"
    static let doubleChime = SoundPreset(
        name: "Double Chime",
        description: "Two tones: 440Hz then 660Hz",
        segments: [
            ToneSegment(
                frequency: 440.0,
                toneDuration: 0.3,
                attackTime: 0.005,
                decayTime: 1.5,
                volume: 0.5
            ),
            ToneSegment(
                frequency: 660.0,
                toneDuration: 0.4,
                delayBefore: 0.15,
                attackTime: 0.005,
                decayTime: 1.2,
                volume: 0.5
            )
        ]
    )

    /// Crisp, higher-pitched bell — clear and bright
    static let brightBell = SoundPreset(
        name: "Bright Bell",
        description: "660Hz, crisp attack, short decay",
        segments: [
            ToneSegment(
                frequency: 660.0,
                harmonics: [
                    Harmonic(multiplier: 2.0, amplitude: 0.25),
                    Harmonic(multiplier: 3.0, amplitude: 0.1)
                ],
                toneDuration: 0.6,
                attackTime: 0.005,
                decayTime: 1.8,
                volume: 0.5
            )
        ]
    )

    /// Short version of the existing end gong — deep and resonant
    static let softGong = SoundPreset(
        name: "Soft Gong",
        description: "196Hz + harmonics, gong-like",
        segments: [
            ToneSegment(
                frequency: 196.0,
                harmonics: [
                    Harmonic(multiplier: 2.5, amplitude: 0.4),
                    Harmonic(multiplier: 4.0, amplitude: 0.2),
                    Harmonic(multiplier: 5.5, amplitude: 0.1)
                ],
                toneDuration: 1.2,
                attackTime: 0.01,
                decayTime: 1.0,
                volume: 0.6
            )
        ]
    )

    /// Three ascending pings — playful rising sequence
    static let triplePing = SoundPreset(
        name: "Triple Ping",
        description: "Three ascending pings: 330, 440, 550Hz",
        segments: [
            ToneSegment(
                frequency: 330.0,
                toneDuration: 0.25,
                attackTime: 0.003,
                decayTime: 2.0,
                volume: 0.45
            ),
            ToneSegment(
                frequency: 440.0,
                toneDuration: 0.25,
                delayBefore: 0.1,
                attackTime: 0.003,
                decayTime: 2.0,
                volume: 0.45
            ),
            ToneSegment(
                frequency: 550.0,
                toneDuration: 0.35,
                delayBefore: 0.1,
                attackTime: 0.003,
                decayTime: 1.5,
                volume: 0.5
            )
        ]
    )
}
