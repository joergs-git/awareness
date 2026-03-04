import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// Published properties allow SwiftUI views to react to changes automatically.
/// Shared between iOS and watchOS targets via #if os() guards.
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    /// On watchOS, use App Group shared defaults so the widget extension can access
    /// the same data as the watch app. On iOS, use standard defaults.
    #if os(watchOS)
    private let defaults: UserDefaults
    /// App Group identifier shared between the watch app and its widget extension
    static let appGroupID = "group.com.joergsflow.awareness.watch"
    #else
    private let defaults = UserDefaults.standard
    #endif

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

        // Smart Guru
        static let smartGuruEnabled     = "smartGuruEnabled"
        static let manualMinInterval    = "manualMinInterval"
        static let manualMaxInterval    = "manualMaxInterval"
        static let manualMinDuration    = "manualMinDuration"
        static let manualMaxDuration    = "manualMaxDuration"
        static let guruAdaptiveState    = "guruAdaptiveState"

        // Practice Cards & Micro-Tasks
        static let todaysPracticeCardID  = "todaysPracticeCardID"
        static let practiceCardDate      = "practiceCardDate"
        static let yesterdaysCardID      = "yesterdaysCardID"
        static let currentMicroTaskID    = "currentMicroTaskID"
        static let microTaskDate         = "microTaskDate"
        static let lastMicroTaskIDs      = "lastMicroTaskIDs"
        static let microTaskShownToday   = "microTaskShownToday"
        static let currentSelfReport     = "currentSelfReport"
        static let practiceCardNotificationHour = "practiceCardNotificationHour"
        static let hasLaunchedBefore = "hasLaunchedBefore"

        #if !os(watchOS)
        static let startGongEnabled     = "startGongEnabled"
        static let endGongEnabled       = "endGongEnabled"
        static let customImagePath      = "customImagePath"
        static let customVideoPath      = "customVideoPath"
        static let vibrationEnabled     = "vibrationEnabled"
        static let endFlashEnabled      = "endFlashEnabled"
        #endif

        #if os(watchOS)
        static let reminderHapticEnabled = "reminderHapticEnabled"
        static let hapticEndEnabled      = "hapticEndEnabled"
        static let endFlashEnabled       = "endFlashEnabled"
        // Legacy key for migration from hapticStartEnabled → reminderHapticEnabled
        static let hapticStartEnabled    = "hapticStartEnabled"
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
            Keys.healthKitPromptShown: false,
            Keys.smartGuruEnabled:    true,
            Keys.practiceCardNotificationHour: 7
        ]

        #if !os(watchOS)
        values[Keys.startGongEnabled]  = true
        values[Keys.endGongEnabled]    = true
        values[Keys.customImagePath]   = ""
        values[Keys.customVideoPath]   = ""
        values[Keys.vibrationEnabled]  = true
        values[Keys.endFlashEnabled]   = true
        #endif

        #if os(watchOS)
        values[Keys.reminderHapticEnabled] = true
        values[Keys.hapticEndEnabled]      = true
        values[Keys.endFlashEnabled]       = true
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

    // MARK: - Smart Guru Properties

    /// Whether the adaptive scheduling guru is enabled
    @Published var smartGuruEnabled: Bool {
        didSet {
            defaults.set(smartGuruEnabled, forKey: Keys.smartGuruEnabled)
            if smartGuruEnabled && guruAdaptiveState == nil {
                // Save current manual settings when guru activates
                defaults.set(minInterval, forKey: Keys.manualMinInterval)
                defaults.set(maxInterval, forKey: Keys.manualMaxInterval)
                defaults.set(minBlackoutDuration, forKey: Keys.manualMinDuration)
                defaults.set(maxBlackoutDuration, forKey: Keys.manualMaxDuration)
            }
            if !smartGuruEnabled {
                // Restore manual settings when guru deactivates
                let savedMin = defaults.double(forKey: Keys.manualMinInterval)
                let savedMax = defaults.double(forKey: Keys.manualMaxInterval)
                let savedMinDur = defaults.double(forKey: Keys.manualMinDuration)
                let savedMaxDur = defaults.double(forKey: Keys.manualMaxDuration)
                if savedMin > 0 { minInterval = savedMin }
                if savedMax > 0 { maxInterval = savedMax }
                if savedMinDur > 0 { minBlackoutDuration = savedMinDur }
                if savedMaxDur > 0 { maxBlackoutDuration = savedMaxDur }
            }
        }
    }

    /// The current adaptive state persisted as JSON in UserDefaults
    var guruAdaptiveState: AdaptiveState? {
        get {
            guard let data = defaults.data(forKey: Keys.guruAdaptiveState) else { return nil }
            return try? JSONDecoder().decode(AdaptiveState.self, from: data)
        }
        set {
            if let newValue = newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.guruAdaptiveState)
            } else {
                defaults.removeObject(forKey: Keys.guruAdaptiveState)
            }
            objectWillChange.send()
        }
    }

    /// Effective min interval — uses guru-adapted value when enabled, otherwise user setting
    var effectiveMinInterval: Double {
        guard smartGuruEnabled, let state = guruAdaptiveState, state.phase == .adapting else {
            return minInterval
        }
        return state.currentMinInterval
    }

    /// Effective max interval — uses guru-adapted value when enabled, otherwise user setting
    var effectiveMaxInterval: Double {
        guard smartGuruEnabled, let state = guruAdaptiveState, state.phase == .adapting else {
            return maxInterval
        }
        return state.currentMaxInterval
    }

    /// Effective min blackout duration — uses guru-adapted value when enabled
    var effectiveMinDuration: Double {
        guard smartGuruEnabled, let state = guruAdaptiveState, state.phase == .adapting else {
            return minBlackoutDuration
        }
        return state.currentMinDuration
    }

    /// Effective max blackout duration — uses guru-adapted value when enabled
    var effectiveMaxDuration: Double {
        guard smartGuruEnabled, let state = guruAdaptiveState, state.phase == .adapting else {
            return maxBlackoutDuration
        }
        return state.currentMaxDuration
    }

    /// Returns a random blackout duration using effective (guru-adapted or manual) values
    func effectiveRandomBlackoutDuration() -> Double {
        let min = effectiveMinDuration
        let max = effectiveMaxDuration
        guard max > min else { return min }
        return Double.random(in: min...max)
    }

    /// Hour to send the daily practice card notification (0-23, default 7)
    @Published var practiceCardNotificationHour: Int {
        didSet { defaults.set(practiceCardNotificationHour, forKey: Keys.practiceCardNotificationHour) }
    }

    // MARK: - Practice Card & Micro-Task State

    /// Read-only: return today's stored practice card without assigning a new one.
    /// Used by the widget extension to avoid racing with the main app or iOS sync.
    func storedPracticeCard() -> PracticeCard? {
        let today = todayString()
        let storedDate = defaults.string(forKey: Keys.practiceCardDate)
        guard storedDate == today,
              let cardID = defaults.string(forKey: Keys.todaysPracticeCardID) else {
            return nil
        }
        return PracticeCard.card(withID: cardID)
    }

    /// Get today's practice card, assigning a new one if needed
    func todaysPracticeCard() -> PracticeCard? {
        let today = todayString()
        let storedDate = defaults.string(forKey: Keys.practiceCardDate)

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

        // Archive yesterday's self-report on day change
        archiveYesterdaysSelfReport()

        // Reset micro-task state for new day
        defaults.removeObject(forKey: Keys.currentMicroTaskID)
        defaults.set(false, forKey: Keys.microTaskShownToday)

        return newCard
    }

    /// Get the current micro-task, auto-assigning one from today's card pool if none exists yet.
    /// This ensures a micro-task is visible from app launch, not just after the first blackout.
    func currentMicroTask() -> MicroTask? {
        let today = todayString()
        let storedDate = defaults.string(forKey: Keys.microTaskDate)

        // If we already have a task for today, return it
        if storedDate == today, let taskID = defaults.string(forKey: Keys.currentMicroTaskID) {
            return MicroTask.allTasks.first { $0.id == taskID }
        }

        // Auto-assign from today's card pool so the task is available immediately
        return assignMicroTask()
    }

    /// Assign a new micro-task from today's card's pool (called after first blackout of day)
    func assignMicroTask() -> MicroTask? {
        guard let card = todaysPracticeCard() else { return nil }

        let today = todayString()
        let lastIDs = defaults.stringArray(forKey: Keys.lastMicroTaskIDs) ?? []
        let pool = MicroTask.tasks(forCardID: card.id).filter { !lastIDs.contains($0.id) }

        guard let task = pool.randomElement() ?? MicroTask.tasks(forCardID: card.id).randomElement() else {
            return nil
        }

        defaults.set(task.id, forKey: Keys.currentMicroTaskID)
        defaults.set(today, forKey: Keys.microTaskDate)
        defaults.set(true, forKey: Keys.microTaskShownToday)

        // Track last 3 micro-task IDs to avoid immediate repeats
        var updated = lastIDs
        updated.append(task.id)
        if updated.count > 3 { updated.removeFirst() }
        defaults.set(updated, forKey: Keys.lastMicroTaskIDs)

        return task
    }

    /// Pick a new random micro-task from today's card pool.
    /// Called after each blackout to rotate the displayed task.
    func rotateMicroTask() -> MicroTask? {
        return assignMicroTask()
    }

    /// Whether a micro-task has been shown today (first blackout already happened)
    var microTaskShownToday: Bool {
        defaults.bool(forKey: Keys.microTaskShownToday)
    }

    // MARK: - Self-Report

    /// Get or create today's self-report
    func currentSelfReportData() -> DailySelfReport {
        if let data = defaults.data(forKey: Keys.currentSelfReport),
           let report = try? JSONDecoder().decode(DailySelfReport.self, from: data),
           report.date == todayString() {
            return report
        }
        let cardID = defaults.string(forKey: Keys.todaysPracticeCardID) ?? ""
        return DailySelfReport(date: todayString(), cardID: cardID, succeeded: 0, noticed: 0, forgot: 0)
    }

    /// Update today's self-report
    func updateSelfReport(_ report: DailySelfReport) {
        if let data = try? JSONEncoder().encode(report) {
            defaults.set(data, forKey: Keys.currentSelfReport)
        }
        objectWillChange.send()
    }

    /// Archive yesterday's self-report to EventStore when the day changes
    private func archiveYesterdaysSelfReport() {
        if let data = defaults.data(forKey: Keys.currentSelfReport),
           let report = try? JSONDecoder().decode(DailySelfReport.self, from: data),
           report.date != todayString() {
            EventStore.shared.archiveSelfReport(report)
        }
        // Reset for new day
        defaults.removeObject(forKey: Keys.currentSelfReport)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
    /// Whether to play a haptic when a notification arrives (reminder nudge)
    @Published var reminderHapticEnabled: Bool {
        didSet { defaults.set(reminderHapticEnabled, forKey: Keys.reminderHapticEnabled) }
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

    // MARK: - First Launch

    /// Whether the app has been launched before (used for onboarding, iOS only)
    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
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
    /// Mix of English and German — intentionally multilingual for a mindful, universal feel.
    static let breathingPhrases = [
        "Breathe.",
        "You are here.",
        "Nichts zu tun.",
        "Nur atmen.",
        "This moment."
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

        // Include Smart Guru state
        context["smartGuruEnabled"] = smartGuruEnabled
        if let stateData = defaults.data(forKey: Keys.guruAdaptiveState) {
            context["guruAdaptiveState"] = stateData
        }

        // Sync today's practice card so both devices show the same card (iOS is leader)
        if let cardID = defaults.string(forKey: Keys.todaysPracticeCardID),
           let cardDate = defaults.string(forKey: Keys.practiceCardDate) {
            context["todaysPracticeCardID"] = cardID
            context["practiceCardDate"] = cardDate
        }

        // Sync micro-task so the watch complication can display it
        if let taskID = defaults.string(forKey: Keys.currentMicroTaskID),
           let taskDate = defaults.string(forKey: Keys.microTaskDate) {
            context["currentMicroTaskID"] = taskID
            context["microTaskDate"] = taskDate
        }

        // Sync today's self-report counters so both devices merge taps
        if let reportData = defaults.data(forKey: Keys.currentSelfReport) {
            context["currentSelfReport"] = reportData
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

        // Smart Guru sync — watch receives state but doesn't run the algorithm
        if let v = context["smartGuruEnabled"] as? Bool { smartGuruEnabled = v }
        if let v = context["guruAdaptiveState"] as? Data {
            defaults.set(v, forKey: Keys.guruAdaptiveState)
        }

        // Apply synced practice card (iOS is leader — watchOS adopts the card)
        if let cardID = context["todaysPracticeCardID"] as? String,
           let cardDate = context["practiceCardDate"] as? String {
            let localCardID = defaults.string(forKey: Keys.todaysPracticeCardID)
            let localDate = defaults.string(forKey: Keys.practiceCardDate)
            if cardID != localCardID || cardDate != localDate {
                defaults.set(cardID, forKey: Keys.todaysPracticeCardID)
                defaults.set(cardDate, forKey: Keys.practiceCardDate)
                objectWillChange.send()
            }
        }

        // Apply synced micro-task (iOS assigns after first blackout, watch reads it)
        if let taskID = context["currentMicroTaskID"] as? String,
           let taskDate = context["microTaskDate"] as? String {
            defaults.set(taskID, forKey: Keys.currentMicroTaskID)
            defaults.set(taskDate, forKey: Keys.microTaskDate)
        }

        // Merge today's self-report counters (max per field prevents double-counting)
        if let reportData = context["currentSelfReport"] as? Data,
           let remote = try? JSONDecoder().decode(DailySelfReport.self, from: reportData),
           remote.date == todayString() {
            let local = currentSelfReportData()
            let merged = DailySelfReport(
                date: remote.date,
                cardID: local.cardID.isEmpty ? remote.cardID : local.cardID,
                succeeded: max(local.succeeded, remote.succeeded),
                noticed: max(local.noticed, remote.noticed),
                forgot: max(local.forgot, remote.forgot)
            )
            updateSelfReport(merged)
        }
    }

    // MARK: - Init

    private init() {
        #if os(watchOS)
        // Use App Group shared UserDefaults so the widget extension sees the same data
        let shared = UserDefaults(suiteName: SettingsManager.appGroupID) ?? .standard
        // One-time migration from standard defaults to shared suite
        if !shared.bool(forKey: "migratedToSharedSuite") {
            let standard = UserDefaults.standard
            for (key, _) in SettingsManager.defaultValues {
                if let value = standard.object(forKey: key) {
                    shared.set(value, forKey: key)
                }
            }
            // Migrate practice card and micro-task keys
            for key in [Keys.todaysPracticeCardID, Keys.practiceCardDate,
                        Keys.yesterdaysCardID, Keys.currentMicroTaskID,
                        Keys.microTaskDate, Keys.lastMicroTaskIDs,
                        Keys.microTaskShownToday, Keys.currentSelfReport,
                        Keys.guruAdaptiveState] {
                if let value = standard.object(forKey: key) {
                    shared.set(value, forKey: key)
                }
            }
            shared.set(true, forKey: "migratedToSharedSuite")
        }
        defaults = shared
        #endif

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
        smartGuruEnabled    = defaults.bool(forKey: Keys.smartGuruEnabled)
        practiceCardNotificationHour = defaults.integer(forKey: Keys.practiceCardNotificationHour)

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
        // Migrate from old hapticStartEnabled → reminderHapticEnabled
        if defaults.object(forKey: Keys.hapticStartEnabled) != nil
            && defaults.object(forKey: Keys.reminderHapticEnabled) == nil {
            let oldValue = defaults.bool(forKey: Keys.hapticStartEnabled)
            defaults.set(oldValue, forKey: Keys.reminderHapticEnabled)
            defaults.removeObject(forKey: Keys.hapticStartEnabled)
        }

        reminderHapticEnabled = defaults.bool(forKey: Keys.reminderHapticEnabled)
        hapticEndEnabled      = defaults.bool(forKey: Keys.hapticEndEnabled)
        endFlashEnabled       = defaults.bool(forKey: Keys.endFlashEnabled)
        #endif
    }
}
