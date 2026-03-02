import Foundation

// MARK: - Smart Guru — Adaptive Mindfulness Scheduling
// Rule-based algorithm that learns the user's rhythm and adapts intervals and duration.
// iOS only — watchOS receives adjusted fire dates via coordinated scheduling.

class SmartGuru {
    static let shared = SmartGuru()

    private let store = EventStore.shared

    // MARK: - Constants

    /// Minimum hours between adjustments
    private let adjustmentCooldownHours: Double = 6

    /// Minimum interval floor (minutes)
    private let minIntervalFloor: Double = 5

    /// Maximum interval ceiling (minutes)
    private let maxIntervalCeiling: Double = 180

    /// Minimum spread between min and max interval (minutes)
    private let minIntervalSpread: Double = 5

    /// Minimum blackout duration floor (seconds)
    private let minDurationFloor: Double = 5

    /// Maximum blackout duration ceiling (seconds)
    private let maxDurationCeiling: Double = 120

    /// Minimum spread between min and max duration (seconds)
    private let minDurationSpread: Double = 5

    /// How many consecutive dismissals before reducing duration
    private let dismissalTrendThreshold: Int = 3

    /// Duration decrease per adaptation step (seconds)
    private let durationDecreaseStep: Double = 5

    /// Duration increase per day of consistent completion (seconds)
    private let durationIncreaseStep: Double = 1

    /// Minimum days of baseline data collection
    private let baselineDays: Int = 3

    /// Minimum events required to end baseline
    private let baselineMinEvents: Int = 6

    private init() {}

    // MARK: - Core Algorithm

    /// Called after each recorded event. Evaluates and potentially adjusts scheduling.
    /// Returns true if an adjustment was made.
    @discardableResult
    func evaluateAfterEvent(_ event: MindfulEvent) -> Bool {
        let settings = SettingsManager.shared
        guard settings.smartGuruEnabled else { return false }

        var state = settings.guruAdaptiveState ?? createInitialState(settings: settings)

        // Check baseline → adapting transition
        if state.phase == .baseline {
            let daysSinceStart = (Date().timeIntervalSince1970 - state.baselineStartDate) / 86400
            let eventCount = store.events.count
            if daysSinceStart >= Double(baselineDays) && eventCount >= baselineMinEvents {
                state.phase = .adapting
            } else {
                settings.guruAdaptiveState = state
                return false
            }
        }

        // Rate-limit: skip if less than cooldown since last adjustment
        if let lastAdj = state.lastAdjustmentDate {
            let hoursSince = (Date().timeIntervalSince1970 - lastAdj) / 3600
            if hoursSince < adjustmentCooldownHours {
                settings.guruAdaptiveState = state
                return false
            }
        }

        // Compute blended success rate
        let recentRate = store.successRate(days: 3)
        let hourRate = store.hourlySuccessRate(hour: event.hourOfDay)
        let hourDataSufficient = store.hourProfileTotal(hour: event.hourOfDay) >= 10

        let blendedRate: Double
        if hourDataSufficient, let hr = hourRate {
            blendedRate = 0.7 * recentRate + 0.3 * hr
        } else {
            blendedRate = recentRate
        }

        var adjusted = false

        // --- Interval adaptation ---
        if blendedRate >= 0.80 && state.streakCompleted >= 3 {
            // Thriving: decrease intervals (more frequent)
            state.currentMinInterval *= 0.90
            state.currentMaxInterval *= 0.90

            // Enforce floors and spread
            state.currentMinInterval = max(state.currentMinInterval, minIntervalFloor)
            state.currentMaxInterval = max(state.currentMaxInterval, state.currentMinInterval + minIntervalSpread)

            adjusted = true
        } else if blendedRate < 0.50 {
            // Struggling: increase intervals (less frequent)
            state.currentMinInterval *= 1.10
            state.currentMaxInterval *= 1.10

            // Enforce ceiling
            state.currentMinInterval = min(state.currentMinInterval, maxIntervalCeiling - minIntervalSpread)
            state.currentMaxInterval = min(state.currentMaxInterval, maxIntervalCeiling)

            adjusted = true
        }
        // 0.50 <= blendedRate < 0.80: sweet spot, hold steady

        // --- Duration adaptation ---
        let durationAdjusted = evaluateDurationAdaptation(&state)
        adjusted = adjusted || durationAdjusted

        // Update streak tracking
        switch event.outcome {
        case .completed:
            state.streakCompleted += 1
            state.streakIgnored = 0
        case .dismissed, .ignored:
            state.streakIgnored += 1
            state.streakCompleted = 0
        }

        if adjusted {
            state.lastAdjustmentDate = Date().timeIntervalSince1970
            state.adjustmentCount += 1
        }

        settings.guruAdaptiveState = state
        return adjusted
    }

    // MARK: - Duration Adaptation

    /// Adjusts blackout duration based on dismissal trends and completion streaks.
    /// Returns true if an adjustment was made.
    private func evaluateDurationAdaptation(_ state: inout AdaptiveState) -> Bool {
        let consecutiveDismissals = store.consecutiveOutcome(.dismissed)

        // Trend of 3+ consecutive dismissals: reduce duration
        if consecutiveDismissals >= dismissalTrendThreshold {
            let newMin = state.currentMinDuration - durationDecreaseStep
            let newMax = state.currentMaxDuration - durationDecreaseStep

            // Enforce floors and spread
            state.currentMinDuration = max(newMin, minDurationFloor)
            state.currentMaxDuration = max(newMax, state.currentMinDuration + minDurationSpread)
            return true
        }

        // Consistent completion over last 7 days: slow increase (~1s/day equivalent)
        // Only when streak is strong (5+ completions in a row)
        if state.streakCompleted >= 5 {
            let sevenDayRate = store.successRate(days: 7)
            if sevenDayRate >= 0.85 {
                // Check if we haven't already increased today
                let today = todayString()
                if state.lastDurationIncreaseDate != today {
                    state.currentMinDuration = min(state.currentMinDuration + durationIncreaseStep, maxDurationCeiling - minDurationSpread)
                    state.currentMaxDuration = min(state.currentMaxDuration + durationIncreaseStep, maxDurationCeiling)
                    state.lastDurationIncreaseDate = today
                    return true
                }
            }
        }

        return false
    }

    // MARK: - State Management

    /// Create initial adaptive state from current settings
    func createInitialState(settings: SettingsManager) -> AdaptiveState {
        AdaptiveState(
            phase: .baseline,
            baselineStartDate: Date().timeIntervalSince1970,
            currentMinInterval: settings.minInterval,
            currentMaxInterval: settings.maxInterval,
            currentMinDuration: settings.minBlackoutDuration,
            currentMaxDuration: settings.maxBlackoutDuration,
            lastAdjustmentDate: nil,
            adjustmentCount: 0,
            streakCompleted: 0,
            streakIgnored: 0,
            lastDurationIncreaseDate: nil
        )
    }

    /// Determine how many practice cards to show today
    func practiceCardCount(state: AdaptiveState?) -> Int {
        guard let state = state, state.phase == .adapting else { return 1 }
        return state.streakCompleted >= 5 ? 2 : 1
    }

    /// Determine how many micro-tasks to show today
    func microTaskCount(state: AdaptiveState?) -> Int {
        guard let state = state, state.phase == .adapting else { return 1 }
        let recentRate = store.successRate(days: 3)
        return recentRate >= 0.70 ? 2 : 1
    }

    /// Human-readable description of current guru state
    func statusDescription(state: AdaptiveState?) -> String {
        guard let state = state else {
            return String(localized: "Not started")
        }

        switch state.phase {
        case .baseline:
            let daysSince = Int((Date().timeIntervalSince1970 - state.baselineStartDate) / 86400) + 1
            return String(localized: "Learning your rhythm (Day \(daysSince) of \(baselineDays))")
        case .adapting:
            let rate = Int(store.successRate(days: 3) * 100)
            return String(localized: "Adapting — \(rate)% discipline (3-day)")
        }
    }

    // MARK: - Helpers

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// AdaptiveState and GuruPhase are defined in MindfulEvent.swift (shared with watchOS)
