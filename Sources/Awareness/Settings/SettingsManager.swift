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
        static let minBlackoutDuration = "minBlackoutDuration"
        static let maxBlackoutDuration = "maxBlackoutDuration"
        static let minInterval         = "minInterval"
        static let maxInterval         = "maxInterval"
        static let startGongEnabled    = "startGongEnabled"
        static let endGongEnabled      = "endGongEnabled"
        static let handcuffsMode       = "handcuffsMode"
        static let visualType          = "visualType"
        static let customText          = "customText"
        static let customImagePath     = "customImagePath"
        static let customVideoPath     = "customVideoPath"
        static let customImageBookmark = "customImageBookmark"
        static let customVideoBookmark = "customVideoBookmark"
        static let snoozeUntil              = "snoozeUntil"
        static let startclickConfirmation   = "startclickConfirmation"

        // Practice Cards & Micro-Tasks
        static let todaysPracticeCardID  = "todaysPracticeCardID"
        static let practiceCardDate      = "practiceCardDate"
        static let yesterdaysCardID      = "yesterdaysCardID"
        static let currentMicroTaskID    = "currentMicroTaskID"
        static let microTaskDate         = "microTaskDate"
        static let lastMicroTaskIDs      = "lastMicroTaskIDs"
    }

    // MARK: - Default Values

    private static let defaultValues: [String: Any] = [
        Keys.activeStartHour:  6,
        Keys.activeEndHour:    22,
        Keys.minBlackoutDuration: 20.0,
        Keys.maxBlackoutDuration: 40.0,
        Keys.minInterval:      15.0,    // minutes
        Keys.maxInterval:      30.0,    // minutes
        Keys.startGongEnabled: true,
        Keys.endGongEnabled:   true,
        Keys.handcuffsMode:    false,
        Keys.visualType:       BlackoutVisualType.text.rawValue,
        Keys.customText:       "Breathe.",
        Keys.customImagePath:  "",
        Keys.customVideoPath:  "",
        Keys.startclickConfirmation: false
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

    /// Minimum blackout duration (seconds)
    @Published var minBlackoutDuration: Double {
        didSet {
            defaults.set(minBlackoutDuration, forKey: Keys.minBlackoutDuration)
            // Enforce: min cannot exceed max
            if minBlackoutDuration > maxBlackoutDuration {
                maxBlackoutDuration = minBlackoutDuration
            }
        }
    }

    /// Maximum blackout duration (seconds)
    @Published var maxBlackoutDuration: Double {
        didSet {
            defaults.set(maxBlackoutDuration, forKey: Keys.maxBlackoutDuration)
            // Enforce: max cannot be less than min
            if maxBlackoutDuration < minBlackoutDuration {
                minBlackoutDuration = maxBlackoutDuration
            }
        }
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

    /// When on, a "Ready to breathe?" prompt appears before each blackout
    @Published var startclickConfirmation: Bool {
        didSet { defaults.set(startclickConfirmation, forKey: Keys.startclickConfirmation) }
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

    /// Default breathing phrases that rotate randomly to prevent habituation.
    /// Shown only when the user hasn't customized the text (i.e. still set to "Breathe.").
    /// Localized per device language via String(localized:).
    static let breathingPhrases: [String] = [
        String(localized: "Breathe."),
        String(localized: "You are here."),
        String(localized: "Nothing to do."),
        String(localized: "Just breathe."),
        String(localized: "This moment.")
    ]

    /// Returns the text to display during a text-mode breathing break.
    /// If the user has the default "Breathe." text, randomly picks from the rotation pool.
    /// If they've customized the text, returns their custom text as-is.
    func resolvedBreathingText() -> String {
        if customText == "Breathe." || customText.isEmpty {
            return Self.breathingPhrases.randomElement() ?? "Breathe."
        }
        return customText
    }

    /// Returns a random blackout duration between min and max (seconds).
    /// If both values are equal, returns the fixed duration.
    func randomBlackoutDuration() -> Double {
        guard maxBlackoutDuration > minBlackoutDuration else { return minBlackoutDuration }
        return Double.random(in: minBlackoutDuration...maxBlackoutDuration)
    }

    // MARK: - Security-Scoped Bookmarks (Sandbox Support)

    /// Store a security-scoped bookmark for a user-selected image URL.
    /// In the sandbox, raw file paths lose access after the app restarts;
    /// bookmarks preserve the access grant across launches.
    func setCustomImageURL(_ url: URL) {
        customImagePath = url.path
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(data, forKey: Keys.customImageBookmark)
        }
    }

    /// Resolve the stored image bookmark back to a usable URL.
    /// Falls back to the raw path if no bookmark exists (works outside sandbox).
    func resolveCustomImageURL() -> URL? {
        if let data = defaults.data(forKey: Keys.customImageBookmark) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    defaults.set(refreshed, forKey: Keys.customImageBookmark)
                }
                return url
            }
        }
        // Fallback: try raw path (works outside sandbox)
        guard !customImagePath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: customImagePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Store a security-scoped bookmark for a user-selected video URL.
    func setCustomVideoURL(_ url: URL) {
        customVideoPath = url.path
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(data, forKey: Keys.customVideoBookmark)
        }
    }

    /// Resolve the stored video bookmark back to a usable URL.
    /// Falls back to the raw path if no bookmark exists (works outside sandbox).
    func resolveCustomVideoURL() -> URL? {
        if let data = defaults.data(forKey: Keys.customVideoBookmark) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    defaults.set(refreshed, forKey: Keys.customVideoBookmark)
                }
                return url
            }
        }
        guard !customVideoPath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: customVideoPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    // MARK: - Practice Card & Micro-Task

    /// Get today's practice card, assigning a new one if the day changed.
    /// Avoids repeating yesterday's card.
    func todaysPracticeCard() -> PracticeCard? {
        let today = todayString()
        let storedDate = defaults.string(forKey: Keys.practiceCardDate)

        // Same day — return stored card
        if storedDate == today, let cardID = defaults.string(forKey: Keys.todaysPracticeCardID) {
            return PracticeCard.card(withID: cardID)
        }

        // New day — assign a random card (avoid yesterday's)
        let yesterdayID = defaults.string(forKey: Keys.todaysPracticeCardID)
        defaults.set(yesterdayID, forKey: Keys.yesterdaysCardID)

        let candidates = PracticeCard.allCards.filter { $0.id != yesterdayID }
        guard let newCard = candidates.randomElement() else { return nil }

        defaults.set(newCard.id, forKey: Keys.todaysPracticeCardID)
        defaults.set(today, forKey: Keys.practiceCardDate)

        // Reset micro-task state for new day
        defaults.removeObject(forKey: Keys.currentMicroTaskID)
        defaults.removeObject(forKey: Keys.microTaskDate)

        return newCard
    }

    /// Pick a new random micro-task from today's card pool.
    /// Tracks last 3 IDs to avoid immediate repeats.
    /// Called after each blackout completion to rotate the displayed task.
    func randomMicroTask() -> MicroTask? {
        guard let card = todaysPracticeCard() else { return nil }

        let lastIDs = defaults.stringArray(forKey: Keys.lastMicroTaskIDs) ?? []
        let pool = MicroTask.tasks(forCardID: card.id).filter { !lastIDs.contains($0.id) }

        // Fallback to full pool if all tasks recently used
        guard let task = pool.randomElement() ?? MicroTask.tasks(forCardID: card.id).randomElement() else {
            return nil
        }

        let today = todayString()
        defaults.set(task.id, forKey: Keys.currentMicroTaskID)
        defaults.set(today, forKey: Keys.microTaskDate)

        // Track last 3 micro-task IDs to avoid immediate repeats
        var updated = lastIDs
        updated.append(task.id)
        if updated.count > 3 { updated.removeFirst() }
        defaults.set(updated, forKey: Keys.lastMicroTaskIDs)

        return task
    }

    /// Helper: today's date as "yyyy-MM-dd"
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
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

        // Migrate: if old "blackoutDuration" key exists, map to both min and max
        if defaults.object(forKey: "blackoutDuration") != nil {
            let oldDuration = defaults.double(forKey: "blackoutDuration")
            if defaults.object(forKey: Keys.minBlackoutDuration) == nil {
                defaults.set(oldDuration, forKey: Keys.minBlackoutDuration)
            }
            if defaults.object(forKey: Keys.maxBlackoutDuration) == nil {
                defaults.set(oldDuration, forKey: Keys.maxBlackoutDuration)
            }
            defaults.removeObject(forKey: "blackoutDuration")
        }

        // Load persisted (or default) values into published properties
        activeStartHour     = defaults.integer(forKey: Keys.activeStartHour)
        activeEndHour       = defaults.integer(forKey: Keys.activeEndHour)
        minBlackoutDuration = defaults.double(forKey: Keys.minBlackoutDuration)
        maxBlackoutDuration = defaults.double(forKey: Keys.maxBlackoutDuration)
        minInterval      = defaults.double(forKey: Keys.minInterval)
        maxInterval      = defaults.double(forKey: Keys.maxInterval)
        startGongEnabled = defaults.bool(forKey: Keys.startGongEnabled)
        endGongEnabled   = defaults.bool(forKey: Keys.endGongEnabled)
        handcuffsMode    = defaults.bool(forKey: Keys.handcuffsMode)
        customText       = defaults.string(forKey: Keys.customText) ?? "Breathe."
        customImagePath  = defaults.string(forKey: Keys.customImagePath) ?? ""
        customVideoPath  = defaults.string(forKey: Keys.customVideoPath) ?? ""
        startclickConfirmation = defaults.bool(forKey: Keys.startclickConfirmation)
        snoozeUntil      = defaults.object(forKey: Keys.snoozeUntil) as? Date

        let typeRaw = defaults.string(forKey: Keys.visualType) ?? BlackoutVisualType.text.rawValue
        visualType = BlackoutVisualType(rawValue: typeRaw) ?? .text
    }
}
