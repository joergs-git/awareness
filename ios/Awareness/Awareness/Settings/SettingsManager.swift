import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// Published properties allow SwiftUI views to react to changes automatically.
/// iOS version — mirrors macOS SettingsManager with identical defaults.
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
        static let startGongEnabled     = "startGongEnabled"
        static let endGongEnabled       = "endGongEnabled"
        static let handcuffsMode        = "handcuffsMode"
        static let visualType           = "visualType"
        static let customText           = "customText"
        static let customImagePath      = "customImagePath"
        static let customVideoPath      = "customVideoPath"
        static let snoozeUntil          = "snoozeUntil"
        static let healthKitEnabled     = "healthKitEnabled"
    }

    // MARK: - Default Values

    private static let defaultValues: [String: Any] = [
        Keys.activeStartHour:     6,
        Keys.activeEndHour:       20,
        Keys.minBlackoutDuration: 20.0,
        Keys.maxBlackoutDuration: 20.0,
        Keys.minInterval:         15.0,    // minutes
        Keys.maxInterval:         30.0,    // minutes
        Keys.startGongEnabled:    true,
        Keys.endGongEnabled:      true,
        Keys.handcuffsMode:       false,
        Keys.visualType:          BlackoutVisualType.text.rawValue,
        Keys.customText:          "Breathe.",
        Keys.customImagePath:     "",
        Keys.customVideoPath:     "",
        Keys.healthKitEnabled:    false
    ]

    // MARK: - Published Properties

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

    /// Whether to play the start gong when a blackout begins
    @Published var startGongEnabled: Bool {
        didSet { defaults.set(startGongEnabled, forKey: Keys.startGongEnabled) }
    }

    /// Whether to play the end gong when a blackout finishes
    @Published var endGongEnabled: Bool {
        didSet { defaults.set(endGongEnabled, forKey: Keys.endGongEnabled) }
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

    /// File path for custom image blackout (relative to app sandbox)
    @Published var customImagePath: String {
        didSet { defaults.set(customImagePath, forKey: Keys.customImagePath) }
    }

    /// File path for custom video blackout (relative to app sandbox)
    @Published var customVideoPath: String {
        didSet { defaults.set(customVideoPath, forKey: Keys.customVideoPath) }
    }

    /// Date until which the app is snoozed (nil = not snoozed)
    @Published var snoozeUntil: Date? {
        didSet { defaults.set(snoozeUntil, forKey: Keys.snoozeUntil) }
    }

    /// Whether to log each blackout session to Apple Health as Mindful Minutes
    @Published var healthKitEnabled: Bool {
        didSet { defaults.set(healthKitEnabled, forKey: Keys.healthKitEnabled) }
    }

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

    /// Resolve a sandbox-relative path to a full URL, or return nil if empty/missing
    static func resolvedURL(for path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
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
        startGongEnabled    = defaults.bool(forKey: Keys.startGongEnabled)
        endGongEnabled      = defaults.bool(forKey: Keys.endGongEnabled)
        handcuffsMode       = defaults.bool(forKey: Keys.handcuffsMode)
        customText          = defaults.string(forKey: Keys.customText) ?? "Breathe."
        customImagePath     = defaults.string(forKey: Keys.customImagePath) ?? ""
        customVideoPath     = defaults.string(forKey: Keys.customVideoPath) ?? ""
        snoozeUntil         = defaults.object(forKey: Keys.snoozeUntil) as? Date
        healthKitEnabled    = defaults.bool(forKey: Keys.healthKitEnabled)

        let typeRaw = defaults.string(forKey: Keys.visualType) ?? BlackoutVisualType.text.rawValue
        visualType = BlackoutVisualType(rawValue: typeRaw) ?? .text
    }
}
