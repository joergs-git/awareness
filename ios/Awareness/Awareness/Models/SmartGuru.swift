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

    /// Minimum interval floor (minutes). Raised from 5 → 8: a break every ~5 min is
    /// counterproductive and risks the user disabling the app. "More often" is still the
    /// goal, just with a saner lower bound.
    private let minIntervalFloor: Double = 8

    /// Maximum interval ceiling (minutes)
    private let maxIntervalCeiling: Double = 180

    /// Minimum spread between min and max interval (minutes)
    private let minIntervalSpread: Double = 5

    /// Minimum meaningful blackout duration (seconds). Raised from 6 → 12: a 6-second
    /// blackout is too short to actually land as a pause, so duration never drops below this.
    private let minDurationFloor: Double = 12

    /// Maximum blackout duration ceiling (seconds)
    private let maxDurationCeiling: Double = 120

    /// Minimum spread between min and max duration (seconds)
    private let minDurationSpread: Double = 5

    /// How many consecutive dismissals (active aborts) before shortening duration
    private let dismissalTrendThreshold: Int = 3

    /// Duration increase per qualifying day (seconds) — slow, goal-directed lengthening
    private let durationIncreaseStep: Double = 1

    /// Awareness window size for the rolling average
    private let awarenessWindowSize: Int = 5

    /// Rolling awareness at/above this (%) is considered strong enough to earn longer breaks
    private let awarenessHighThreshold: Double = 55.0

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

        // Rate-limit: skip adjustments if less than cooldown since the last one.
        // Streaks are still updated below so they stay current between adjustments.
        let cooldownActive: Bool = {
            guard let lastAdj = state.lastAdjustmentDate else { return false }
            return (Date().timeIntervalSince1970 - lastAdj) / 3600 < adjustmentCooldownHours
        }()

        var adjusted = false
        if !cooldownActive {
            // Interval and duration are driven by ONE controller each — no stacking.
            adjusted = adjustInterval(&state, event: event) || adjusted
            adjusted = adjustDuration(&state) || adjusted
        }

        // Update completion streak (drives "earned" lengthening). Any non-completion
        // (dismissed or ignored) resets it.
        state.streakCompleted = (event.outcome == .completed) ? state.streakCompleted + 1 : 0

        if adjusted {
            state.lastAdjustmentDate = Date().timeIntervalSince1970
            state.adjustmentCount += 1
        }

        settings.guruAdaptiveState = state
        return adjusted
    }

    // MARK: - Interval Adaptation

    /// Adjusts intervals from the *engaged* success rate (ignores are excluded upstream).
    /// Thriving → more frequent; struggling → less frequent; sweet spot → hold.
    /// Returns true if an adjustment was made.
    private func adjustInterval(_ state: inout AdaptiveState, event: MindfulEvent) -> Bool {
        // Engaged-only rate. No engaged events in the window ⇒ hold (don't let an idle
        // device push intervals to the ceiling and mute the guru).
        guard let recentRate = store.engagedSuccessRate(days: 3) else { return false }

        // Blend with the time-of-day engaged rate once enough samples exist.
        let blendedRate: Double
        if store.hourProfileTotal(hour: event.hourOfDay) >= 10,
           let hourRate = store.hourlySuccessRate(hour: event.hourOfDay) {
            blendedRate = 0.7 * recentRate + 0.3 * hourRate
        } else {
            blendedRate = recentRate
        }

        if blendedRate >= 0.80 && state.streakCompleted >= 3 {
            // Thriving: more frequent
            state.currentMinInterval = max(state.currentMinInterval * 0.90, minIntervalFloor)
            state.currentMaxInterval = max(state.currentMaxInterval * 0.90, state.currentMinInterval + minIntervalSpread)
            return true
        } else if blendedRate < 0.50 {
            // Struggling: less frequent
            state.currentMinInterval = min(state.currentMinInterval * 1.10, maxIntervalCeiling - minIntervalSpread)
            state.currentMaxInterval = min(state.currentMaxInterval * 1.10, maxIntervalCeiling)
            return true
        }
        // 0.50 ≤ blendedRate < 0.80: sweet spot, hold steady
        return false
    }

    // MARK: - Duration Adaptation (single unified controller)

    /// One controller for blackout duration — emits AT MOST ONE step per evaluation,
    /// so signals can never stack into a large drop. Direction priority:
    ///   1. Active rejection (≥3 consecutive dismissals) → shorten (safety brake).
    ///   2. Sustained high awareness + completion → lengthen (earned).
    ///   3. Comfort zone (engaged 0.5–0.8, no dismissals) → gentle goal-directed drift up.
    /// Low awareness on its own NEVER shortens: for a mindfulness pause, a shorter break
    /// only lands less. We hold and let behaviour (dismissals) be the brake — this removes
    /// the old downward "awareness death-spiral". Deliberate jitter is kept in the step size
    /// to prevent habituation to a fixed duration.
    private func adjustDuration(_ state: inout AdaptiveState) -> Bool {
        // 1. Behavioural brake — the user is actively bailing out.
        if store.consecutiveOutcome(.dismissed) >= dismissalTrendThreshold {
            let step = Double.random(in: 3...8) // jitter: anti-habituation, single step only
            state.currentMinDuration = max(state.currentMinDuration - step, minDurationFloor)
            state.currentMaxDuration = max(state.currentMaxDuration - step, state.currentMinDuration + minDurationSpread)
            return true
        }

        // Lengthening is capped to once per day.
        let today = todayString()
        guard state.lastDurationIncreaseDate != today else { return false }

        // 2. Earned lengthening: awareness consistently strong AND breaks completed.
        if let avg = store.rollingAwarenessAverage(last: awarenessWindowSize),
           avg >= awarenessHighThreshold, state.streakCompleted >= 3 {
            return increaseDuration(&state, today: today)
        }

        // 3. Gentle goal-directed drift while comfortable (pursues "longer" actively).
        if let rate = store.engagedSuccessRate(days: 3), rate >= 0.50, rate < 0.80,
           store.consecutiveOutcome(.dismissed) == 0, state.streakCompleted >= 2 {
            return increaseDuration(&state, today: today)
        }

        return false
    }

    /// Slow, bounded duration increase (one step), respecting ceiling and spread.
    private func increaseDuration(_ state: inout AdaptiveState, today: String) -> Bool {
        state.currentMinDuration = min(state.currentMinDuration + durationIncreaseStep, maxDurationCeiling - minDurationSpread)
        state.currentMaxDuration = min(state.currentMaxDuration + durationIncreaseStep, maxDurationCeiling)
        state.lastDurationIncreaseDate = today
        return true
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
            // Engaged rate (ignored breaks excluded) — honest reflection of real discipline.
            let rate = Int((store.engagedSuccessRate(days: 3) ?? 0) * 100)
            // Surface goal-directed lengthening when the guru has grown breaks past the baseline.
            if state.currentMaxDuration > SettingsManager.shared.maxBlackoutDuration {
                return String(localized: "Adapting — \(rate)% engaged · gently lengthening your pauses")
            }
            return String(localized: "Adapting — \(rate)% engaged (3-day)")
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
