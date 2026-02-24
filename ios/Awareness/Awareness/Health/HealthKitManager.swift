import HealthKit

/// Manages HealthKit integration for logging mindful sessions.
/// After each blackout, the actual time spent is saved as a mindful session
/// that appears in Apple Health under "Mindful Minutes".
class HealthKitManager {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let mindfulType = HKCategoryType(.mindfulSession)

    /// Whether HealthKit is available on this device (not available on iPad simulator)
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {}

    /// Request write authorization for mindful sessions.
    /// Returns true if authorization was granted.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            // Request write-only access — we don't need to read mindful sessions
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
            return isAuthorized()
        } catch {
            return false
        }
    }

    /// Check current authorization status for writing mindful sessions
    func isAuthorized() -> Bool {
        guard isAvailable else { return false }
        return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    /// Save a mindful session with the given start and end dates.
    /// Silently skips if not authorized (user may have denied access).
    func saveMindfulSession(start: Date, end: Date) async {
        guard isAvailable, isAuthorized() else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        do {
            try await store.save(sample)
        } catch {
            // Silently ignore — saving to Health is best-effort
        }
    }
}
