import Foundation

/// 256 nature/zen-themed words for generating memorable sync passphrases.
/// Used by SyncKeyManager to create 4-word + number sync keys.
enum SyncWordList {

    static let words: [String] = [
        // Water & sky
        "brook", "creek", "delta", "fjord", "lake", "marsh", "ocean", "pond",
        "rain", "river", "shore", "spray", "steam", "storm", "surge", "tide",
        "cloud", "dawn", "dusk", "glow", "haze", "light", "mist", "moon",
        "sky", "star", "sun", "wind", "breeze", "drift", "frost", "snow",

        // Earth & stone
        "bluff", "cairn", "cave", "chalk", "clay", "cliff", "crag", "dune",
        "earth", "flint", "hill", "knoll", "mesa", "peak", "ridge", "sand",
        "shale", "shore", "slope", "stone", "vale", "gorge", "ledge", "arch",

        // Trees & plants
        "alder", "aspen", "birch", "cedar", "elm", "fern", "grove", "hazel",
        "ivy", "larch", "leaf", "maple", "moss", "oak", "palm", "pine",
        "reed", "root", "sage", "seed", "stem", "thorn", "vine", "willow",
        "bloom", "clover", "daisy", "flora", "iris", "lilac", "lotus", "petal",

        // Animals & birds
        "crane", "dove", "eagle", "finch", "hawk", "heron", "lark", "owl",
        "robin", "raven", "swift", "wren", "bear", "deer", "elk", "fox",
        "hare", "lynx", "otter", "seal", "wolf", "coral", "pearl", "shell",

        // Fire & warmth
        "amber", "blaze", "coal", "ember", "flame", "forge", "glow", "hearth",
        "spark", "torch", "ash", "char", "flare", "heat", "kiln", "smelt",

        // Calm & mind
        "calm", "ease", "grace", "haven", "peace", "quiet", "rest", "still",
        "breath", "depth", "dream", "field", "flow", "path", "pulse", "trail",
        "void", "whole", "clear", "deep", "pure", "soft", "warm", "wise",

        // Time & cycle
        "dew", "equinox", "harvest", "noon", "orbit", "phase", "season", "solstice",
        "spring", "summer", "autumn", "winter", "morning", "evening", "night", "year",

        // Colors & light
        "azure", "blush", "copper", "crimson", "gold", "indigo", "ivory", "jade",
        "opal", "ochre", "rust", "scarlet", "silver", "teal", "umber", "violet",

        // Landscape & space
        "bay", "cove", "dale", "glade", "heath", "isle", "knot", "lagoon",
        "meadow", "oasis", "plain", "rift", "shoal", "steppe", "summit", "tundra",

        // Texture & form
        "arc", "band", "curl", "edge", "fold", "grain", "husk", "knit",
        "loop", "notch", "plume", "ring", "shard", "spire", "weave", "whorl",

        // Sound & air
        "bell", "chime", "drone", "echo", "hum", "lull", "murmur", "note",
        "ripple", "sigh", "song", "tone", "wave", "whirl", "whisper", "zephyr"
    ]
}
