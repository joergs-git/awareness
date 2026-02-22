import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// Published properties allow SwiftUI views to react to changes automatically.
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let activeStartHour     = "activeStartHour"
        static let activeEndHour       = "activeEndHour"
        static let blackoutDuration    = "blackoutDuration"
        static let minInterval         = "minInterval"
        static let maxInterval         = "maxInterval"
        static let startGongEnabled    = "startGongEnabled"
        static let endGongEnabled      = "endGongEnabled"
        static let handcuffsMode       = "handcuffsMode"
        static let visualType          = "visualType"
        static let customText          = "customText"
        static let customImagePath     = "customImagePath"
        static let customVideoPath     = "customVideoPath"
        static let snoozeUntil         = "snoozeUntil"
    }

    // MARK: - Default Values

    private static let defaultValues: [String: Any] = [
        Keys.activeStartHour:  6,
        Keys.activeEndHour:    20,
        Keys.blackoutDuration: 20.0,
        Keys.minInterval:      15.0,    // minutes
        Keys.maxInterval:      30.0,    // minutes
        Keys.startGongEnabled: true,
        Keys.endGongEnabled:   true,
        Keys.handcuffsMode:    false,
        Keys.visualType:       BlackoutVisualType.text.rawValue,
        Keys.customText:       "Breathe.",
        Keys.customImagePath:  "",
        Keys.customVideoPath:  ""
    ]

    // MARK: - Published Properties

    /// Start hour of the active time window (0–23)
    @Published var activeStartHour: Int {
        didSet { defaults.set(activeStartHour, forKey: Keys.activeStartHour) }
    }

    /// End hour of the active time window (0–23)
    @Published var activeEndHour: Int {
        didSet { defaults.set(activeEndHour, forKey: Keys.activeEndHour) }
    }

    /// How long each blackout lasts (seconds)
    @Published var blackoutDuration: Double {
        didSet { defaults.set(blackoutDuration, forKey: Keys.blackoutDuration) }
    }

    /// Minimum delay between blackouts (minutes)
    @Published var minInterval: Double {
        didSet {
            defaults.set(minInterval, forKey: Keys.minInterval)
            // Enforce: min cannot exceed max
            if minInterval > maxInterval {
                maxInterval = minInterval
            }
        }
    }

    /// Maximum delay between blackouts (minutes)
    @Published var maxInterval: Double {
        didSet {
            defaults.set(maxInterval, forKey: Keys.maxInterval)
            // Enforce: max cannot be less than min
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

    /// File path for custom image blackout
    @Published var customImagePath: String {
        didSet { defaults.set(customImagePath, forKey: Keys.customImagePath) }
    }

    /// File path for custom video blackout
    @Published var customVideoPath: String {
        didSet { defaults.set(customVideoPath, forKey: Keys.customVideoPath) }
    }

    /// Date until which the app is snoozed (nil = not snoozed)
    @Published var snoozeUntil: Date? {
        didSet { defaults.set(snoozeUntil, forKey: Keys.snoozeUntil) }
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

    // MARK: - Init

    private init() {
        // Register defaults so first launch has sensible values
        defaults.register(defaults: SettingsManager.defaultValues)

        // Migrate: if old "gongEnabled" key exists, use it for both new keys
        if defaults.object(forKey: "gongEnabled") != nil {
            let oldValue = defaults.bool(forKey: "gongEnabled")
            if defaults.object(forKey: Keys.startGongEnabled) == nil {
                defaults.set(oldValue, forKey: Keys.startGongEnabled)
            }
            if defaults.object(forKey: Keys.endGongEnabled) == nil {
                defaults.set(oldValue, forKey: Keys.endGongEnabled)
            }
            defaults.removeObject(forKey: "gongEnabled")
        }

        // Load persisted (or default) values into published properties
        activeStartHour  = defaults.integer(forKey: Keys.activeStartHour)
        activeEndHour    = defaults.integer(forKey: Keys.activeEndHour)
        blackoutDuration = defaults.double(forKey: Keys.blackoutDuration)
        minInterval      = defaults.double(forKey: Keys.minInterval)
        maxInterval      = defaults.double(forKey: Keys.maxInterval)
        startGongEnabled = defaults.bool(forKey: Keys.startGongEnabled)
        endGongEnabled   = defaults.bool(forKey: Keys.endGongEnabled)
        handcuffsMode    = defaults.bool(forKey: Keys.handcuffsMode)
        customText       = defaults.string(forKey: Keys.customText) ?? "Breathe."
        customImagePath  = defaults.string(forKey: Keys.customImagePath) ?? ""
        customVideoPath  = defaults.string(forKey: Keys.customVideoPath) ?? ""
        snoozeUntil      = defaults.object(forKey: Keys.snoozeUntil) as? Date

        let typeRaw = defaults.string(forKey: Keys.visualType) ?? BlackoutVisualType.text.rawValue
        visualType = BlackoutVisualType(rawValue: typeRaw) ?? .text
    }
}
