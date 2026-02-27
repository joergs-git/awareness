import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// Published properties allow SwiftUI views to react to changes automatically.
/// Shared between iOS and watchOS targets via #if os() guards.
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let activeStartHour      = "activeStartHour"
        static let activeEndHour        = "activeEndHour"
        static let minBlackoutDuration  = "minBlackoutDuration"
        static let maxBlackoutDuration  = "maxBlackoutDuration"
        static let minInterval          = "minInterval"
        static let maxInterval          = "maxInterval"
        static let handcuffsMode        = "handcuffsMode"
        static let visualType           = "visualType"
        static let customText           = "customText"
        static let snoozeUntil          = "snoozeUntil"
        static let healthKitEnabled     = "healthKitEnabled"
        static let healthKitPromptShown = "healthKitPromptShown"

        #if !os(watchOS)
        static let startGongEnabled     = "startGongEnabled"
        static let endGongEnabled       = "endGongEnabled"
        static let customImagePath      = "customImagePath"
        static let customVideoPath      = "customVideoPath"
        static let vibrationEnabled     = "vibrationEnabled"
        static let endFlashEnabled      = "endFlashEnabled"
        #endif

        #if os(watchOS)
        static let hapticStartEnabled   = "hapticStartEnabled"
        static let hapticEndEnabled     = "hapticEndEnabled"
        static let endFlashEnabled      = "endFlashEnabled"
        #endif
    }

    // MARK: - Default Values

    private static var defaultValues: [String: Any] {
        var values: [String: Any] = [
            Keys.activeStartHour:     6,
            Keys.activeEndHour:       22,
            Keys.minBlackoutDuration: 20.0,
            Keys.maxBlackoutDuration: 40.0,
            Keys.minInterval:         15.0,    // minutes
            Keys.maxInterval:         30.0,    // minutes
            Keys.handcuffsMode:       false,
            Keys.visualType:          BlackoutVisualType.text.rawValue,
            Keys.customText:          "Breathe.",
            Keys.healthKitEnabled:    false,
            Keys.healthKitPromptShown: false
        ]

        #if !os(watchOS)
        values[Keys.startGongEnabled]  = true
        values[Keys.endGongEnabled]    = true
        values[Keys.customImagePath]   = ""
        values[Keys.customVideoPath]   = ""
        values[Keys.vibrationEnabled]  = false
        values[Keys.endFlashEnabled]   = true
        #endif

        #if os(watchOS)
        values[Keys.hapticStartEnabled] = true
        values[Keys.hapticEndEnabled]   = true
        values[Keys.endFlashEnabled]    = true
        #endif

        return values
    }

    // MARK: - Published Properties (shared)

    /// Start hour of the active time window (0-23)
    @Published var activeStartHour: Int {
        didSet { defaults.set(activeStartHour, forKey: Keys.activeStartHour) }
    }

    /// End hour of the active time window (0-23)
    @Published var activeEndHour: Int {
        didSet { defaults.set(activeEndHour, forKey: Keys.activeEndHour) }
    }

    /// Minimum blackout duration (seconds)
    @Published var minBlackoutDuration: Double {
        didSet {
            defaults.set(minBlackoutDuration, forKey: Keys.minBlackoutDuration)
            if minBlackoutDuration > maxBlackoutDuration {
                maxBlackoutDuration = minBlackoutDuration
            }
        }
    }

    /// Maximum blackout duration (seconds)
    @Published var maxBlackoutDuration: Double {
        didSet {
            defaults.set(maxBlackoutDuration, forKey: Keys.maxBlackoutDuration)
            if maxBlackoutDuration < minBlackoutDuration {
                minBlackoutDuration = maxBlackoutDuration
            }
        }
    }

    /// Minimum delay between blackouts (minutes)
    @Published var minInterval: Double {
        didSet {
            defaults.set(minInterval, forKey: Keys.minInterval)
            if minInterval > maxInterval {
                maxInterval = minInterval
            }
        }
    }

    /// Maximum delay between blackouts (minutes)
    @Published var maxInterval: Double {
        didSet {
            defaults.set(maxInterval, forKey: Keys.maxInterval)
            if maxInterval < minInterval {
                minInterval = maxInterval
            }
        }
    }

    /// When on, the user cannot dismiss the blackout early
    @Published var handcuffsMode: Bool {
        didSet { defaults.set(handcuffsMode, forKey: Keys.handcuffsMode) }
    }

    /// What visual to show during blackout
    @Published var visualType: BlackoutVisualType {
        didSet { defaults.set(visualType.rawValue, forKey: Keys.visualType) }
    }

    /// Custom text displayed during text-mode blackout
    @Published var customText: String {
        didSet { defaults.set(customText, forKey: Keys.customText) }
    }

    /// Date until which the app is snoozed (nil = not snoozed)
    @Published var snoozeUntil: Date? {
        didSet { defaults.set(snoozeUntil, forKey: Keys.snoozeUntil) }
    }

    /// Whether to log each blackout session to Apple Health as Mindful Minutes
    @Published var healthKitEnabled: Bool {
        didSet { defaults.set(healthKitEnabled, forKey: Keys.healthKitEnabled) }
    }

    /// Whether the HealthKit encouragement prompt has been shown (only ask once)
    @Published var healthKitPromptShown: Bool {
        didSet { defaults.set(healthKitPromptShown, forKey: Keys.healthKitPromptShown) }
    }

    // MARK: - Published Properties (iOS only)

    #if !os(watchOS)
    /// Whether to play the start gong when a blackout begins
    @Published var startGongEnabled: Bool {
        didSet { defaults.set(startGongEnabled, forKey: Keys.startGongEnabled) }
    }

    /// Whether to play the end gong when a blackout finishes
    @Published var endGongEnabled: Bool {
        didSet { defaults.set(endGongEnabled, forKey: Keys.endGongEnabled) }
    }

    /// File path for custom image blackout (relative to app sandbox)
    @Published var customImagePath: String {
        didSet { defaults.set(customImagePath, forKey: Keys.customImagePath) }
    }

    /// File path for custom video blackout (relative to app sandbox)
    @Published var customVideoPath: String {
        didSet { defaults.set(customVideoPath, forKey: Keys.customVideoPath) }
    }

    /// Whether to vibrate at the start and end of a blackout
    @Published var vibrationEnabled: Bool {
        didSet { defaults.set(vibrationEnabled, forKey: Keys.vibrationEnabled) }
    }

    /// Whether to flash white at the end of a blackout (visible through closed eyelids)
    @Published var endFlashEnabled: Bool {
        didSet { defaults.set(endFlashEnabled, forKey: Keys.endFlashEnabled) }
    }
    #endif

    // MARK: - Published Properties (watchOS only)

    #if os(watchOS)
    /// Whether to play haptic at start of blackout
    @Published var hapticStartEnabled: Bool {
        didSet { defaults.set(hapticStartEnabled, forKey: Keys.hapticStartEnabled) }
    }

    /// Whether to play haptic at end of blackout
    @Published var hapticEndEnabled: Bool {
        didSet { defaults.set(hapticEndEnabled, forKey: Keys.hapticEndEnabled) }
    }

    /// Whether to flash white at the end of a blackout (visible through closed eyelids)
    @Published var endFlashEnabled: Bool {
        didSet { defaults.set(endFlashEnabled, forKey: Keys.endFlashEnabled) }
    }
    #endif

    // MARK: - Computed Helpers

    /// The active time window as a TimeWindow model
    var activeTimeWindow: TimeWindow {
        TimeWindow(startHour: activeStartHour, endHour: activeEndHour)
    }

    /// Whether the app is currently snoozed
    var isSnoozed: Bool {
        guard let until = snoozeUntil else { return false }
        return Date() < until
    }

    /// Returns a random blackout duration between min and max (seconds).
    /// If both values are equal, returns the fixed duration.
    func randomBlackoutDuration() -> Double {
        guard maxBlackoutDuration > minBlackoutDuration else { return minBlackoutDuration }
        return Double.random(in: minBlackoutDuration...maxBlackoutDuration)
    }

    #if !os(watchOS)
    /// Resolve a sandbox-relative path to a full URL, or return nil if empty/missing
    static func resolvedURL(for path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    #endif

    // MARK: - WatchConnectivity Sync

    /// Keys that are synced between iOS and watchOS via WCSession applicationContext
    private static let syncedKeys: [String] = [
        "activeStartHour", "activeEndHour",
        "minBlackoutDuration", "maxBlackoutDuration",
        "minInterval", "maxInterval",
        "handcuffsMode", "customText",
        "healthKitEnabled", "snoozeUntil",
        "visualType"
    ]

    /// Export settings that should be synced to the companion device
    func connectivityContext() -> [String: Any] {
        var context: [String: Any] = [
            "activeStartHour":     activeStartHour,
            "activeEndHour":       activeEndHour,
            "minBlackoutDuration": minBlackoutDuration,
            "maxBlackoutDuration": maxBlackoutDuration,
            "minInterval":         minInterval,
            "maxInterval":         maxInterval,
            "handcuffsMode":       handcuffsMode,
            "customText":          customText,
            "healthKitEnabled":    healthKitEnabled,
            "visualType":          visualType.rawValue
        ]

        // Include snooze state if currently snoozed
        if let snoozeUntil = snoozeUntil {
            context["snoozeUntil"] = snoozeUntil.timeIntervalSince1970
        } else {
            context["snoozeUntil"] = 0.0
        }

        return context
    }

    /// Apply settings received from the companion device via WCSession
    func applyFromConnectivityContext(_ context: [String: Any]) {
        if let v = context["activeStartHour"] as? Int { activeStartHour = v }
        if let v = context["activeEndHour"] as? Int { activeEndHour = v }
        if let v = context["minBlackoutDuration"] as? Double { minBlackoutDuration = v }
        if let v = context["maxBlackoutDuration"] as? Double { maxBlackoutDuration = v }
        if let v = context["minInterval"] as? Double { minInterval = v }
        if let v = context["maxInterval"] as? Double { maxInterval = v }
        if let v = context["handcuffsMode"] as? Bool { handcuffsMode = v }
        if let v = context["customText"] as? String { customText = v }
        if let v = context["healthKitEnabled"] as? Bool { healthKitEnabled = v }
        if let v = context["visualType"] as? String {
            visualType = BlackoutVisualType(rawValue: v) ?? .text
        }

        // Handle snooze sync — 0 means not snoozed
        if let v = context["snoozeUntil"] as? Double {
            snoozeUntil = v > 0 ? Date(timeIntervalSince1970: v) : nil
        }
    }

    // MARK: - Init

    private init() {
        defaults.register(defaults: SettingsManager.defaultValues)

        // Load persisted (or default) values into published properties
        activeStartHour     = defaults.integer(forKey: Keys.activeStartHour)
        activeEndHour       = defaults.integer(forKey: Keys.activeEndHour)
        minBlackoutDuration = defaults.double(forKey: Keys.minBlackoutDuration)
        maxBlackoutDuration = defaults.double(forKey: Keys.maxBlackoutDuration)
        minInterval         = defaults.double(forKey: Keys.minInterval)
        maxInterval         = defaults.double(forKey: Keys.maxInterval)
        handcuffsMode       = defaults.bool(forKey: Keys.handcuffsMode)
        customText          = defaults.string(forKey: Keys.customText) ?? "Breathe."
        snoozeUntil         = defaults.object(forKey: Keys.snoozeUntil) as? Date
        healthKitEnabled    = defaults.bool(forKey: Keys.healthKitEnabled)
        healthKitPromptShown = defaults.bool(forKey: Keys.healthKitPromptShown)

        let typeRaw = defaults.string(forKey: Keys.visualType) ?? BlackoutVisualType.text.rawValue
        visualType = BlackoutVisualType(rawValue: typeRaw) ?? .text

        #if !os(watchOS)
        startGongEnabled    = defaults.bool(forKey: Keys.startGongEnabled)
        endGongEnabled      = defaults.bool(forKey: Keys.endGongEnabled)
        customImagePath     = defaults.string(forKey: Keys.customImagePath) ?? ""
        customVideoPath     = defaults.string(forKey: Keys.customVideoPath) ?? ""
        vibrationEnabled    = defaults.bool(forKey: Keys.vibrationEnabled)
        endFlashEnabled     = defaults.bool(forKey: Keys.endFlashEnabled)
        #endif

        #if os(watchOS)
        hapticStartEnabled  = defaults.bool(forKey: Keys.hapticStartEnabled)
        hapticEndEnabled    = defaults.bool(forKey: Keys.hapticEndEnabled)
        endFlashEnabled     = defaults.bool(forKey: Keys.endFlashEnabled)
        #endif
    }
}
