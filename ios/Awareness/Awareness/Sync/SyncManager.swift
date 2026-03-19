import Foundation

/// Orchestrates bidirectional Supabase sync for iOS:
/// - Pulls desktop/watchOS events and integrates into ProgressTracker + HealthKit
/// - Uploads iOS blackout events so other platforms can coordinate triggers
final class SyncManager: ObservableObject {

    static let shared = SyncManager()

    /// Whether the last Supabase operation succeeded (for UI status indicator)
    @Published private(set) var isSyncOnline: Bool = false

    /// Prevents concurrent pull operations
    private var isPulling = false

    private let defaults = UserDefaults.standard
    private let pendingKey = "syncPendingUploadEvents"
    private let maxPendingEvents = 500
    private let maxPendingAgeDays = 7

    // MARK: - Pull & Integrate

    /// Fetch new desktop events from Supabase and integrate into local stats + HealthKit.
    /// Excludes iOS and watchOS events (watchOS syncs progress via WCSession).
    /// Called on app open, after local blackout, and on foreground return.
    /// Silently fails on network errors — the cursor ensures catch-up on next success.
    func pullAndIntegrate() {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return }
        guard !isPulling else { return }

        isPulling = true

        Task {
            defer { isPulling = false }

            do {
                let since = SyncKeyManager.shared.lastPullDate
                // Only pull desktop events — watchOS progress is synced via WCSession
                let events = try await SupabaseClient.shared.fetchEvents(
                    syncKeyHash: syncKeyHash,
                    since: since,
                    excludeSources: ["ios", "watchos"]
                )

                await MainActor.run { isSyncOnline = true }
                guard !events.isEmpty else { return }

                var processedIDs = SyncKeyManager.shared.processedEventIDs
                var latestDate: Date?
                var latestBreakEndTime: Date?
                var integrated = false

                for event in events {
                    // Skip already-processed events
                    guard !processedIDs.contains(event.id) else { continue }

                    // Parse the event timestamp for date key and HealthKit
                    guard let startedAt = SupabaseClient.parseDate(event.startedAt) else { continue }

                    // Convert to local date key for ProgressTracker daily records
                    let dateKey = Self.dateKey(for: startedAt)

                    // Map awareness string to score (supports both old and new formats)
                    let awarenessScore: Int? = {
                        guard let str = event.awareness else { return nil }
                        // New format: numeric string ("75")
                        if let num = Int(str) { return max(0, min(100, num)) }
                        // Old format: "yes"/"somewhat"/"no"
                        switch str {
                        case "yes": return 100
                        case "somewhat": return 50
                        case "no": return 0
                        default: return nil
                        }
                    }()

                    // Integrate into ProgressTracker
                    ProgressTracker.shared.integrateRemoteEvent(
                        date: dateKey,
                        completed: event.completed,
                        awarenessScore: awarenessScore
                    )

                    // Store in local event log for cross-platform analytics
                    LocalEventLog.shared.recordFromBlackout(
                        startedAt: startedAt,
                        duration: event.duration,
                        completed: event.completed,
                        awarenessScore: awarenessScore,
                        source: event.source
                    )

                    // Log to HealthKit if completed and enabled
                    if event.completed && SettingsManager.shared.healthKitEnabled {
                        let endDate = startedAt.addingTimeInterval(event.duration)
                        Task {
                            await HealthKitManager.shared.saveMindfulSession(
                                start: startedAt,
                                end: endDate
                            )
                        }
                    }

                    // Track as processed
                    processedIDs.insert(event.id)
                    integrated = true

                    // Track latest break end time for scheduler postpone
                    let breakEnd = startedAt.addingTimeInterval(event.duration)
                    if latestBreakEndTime == nil || breakEnd > latestBreakEndTime! {
                        latestBreakEndTime = breakEnd
                    }

                    // Track latest created_at for cursor
                    if let createdAt = SupabaseClient.parseDate(event.createdAt) {
                        if latestDate == nil || createdAt > latestDate! {
                            latestDate = createdAt
                        }
                    }
                }

                // Update sync state
                if let latestDate = latestDate {
                    SyncKeyManager.shared.lastPullDate = latestDate
                }

                // Prune old processed IDs (keep last 90 days worth)
                pruneProcessedIDs(&processedIDs)
                SyncKeyManager.shared.processedEventIDs = processedIDs

                // Refresh widget if we integrated any events
                if integrated {
                    await MainActor.run {
                        WidgetDataBridge.shared.updateWidget()
                    }
                }

                // Postpone iOS schedulers if a desktop break just ended recently.
                // Avoids double-triggering (e.g. Mac break at 10:00, iOS fires at 10:01).
                if let breakEnd = latestBreakEndTime {
                    let minInterval = SettingsManager.shared.effectiveMinInterval * 60.0
                    let timeSinceBreak = Date().timeIntervalSince(breakEnd)
                    if timeSinceBreak < minInterval && timeSinceBreak >= 0 {
                        let postponeUntil = breakEnd.addingTimeInterval(minInterval)
                        await MainActor.run {
                            ForegroundScheduler.shared.postponeIfNeeded(until: postponeUntil)
                        }
                    }
                }
            } catch {
                await MainActor.run { isSyncOnline = false }
                print("Awareness Sync: pull failed — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Pre-Trigger Check

    /// Quick check: was there a recent break on any other device that should prevent iOS from triggering?
    /// Checks macOS, Windows, and watchOS events. Called by ForegroundScheduler right before firing.
    /// Returns true if iOS should NOT trigger (another device's break was recent).
    func shouldDeferToRecentBreak() async -> Bool {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return false }

        do {
            let since = SyncKeyManager.shared.lastPullDate
            // Check all non-iOS sources (macOS, Windows, watchOS)
            let events = try await SupabaseClient.shared.fetchEvents(
                syncKeyHash: syncKeyHash,
                since: since,
                excludeSources: ["ios"]
            )

            guard !events.isEmpty else { return false }

            // Find the latest break end time among new events
            var latestBreakEnd: Date?
            for event in events {
                guard let startedAt = SupabaseClient.parseDate(event.startedAt) else { continue }
                let breakEnd = startedAt.addingTimeInterval(event.duration)
                if latestBreakEnd == nil || breakEnd > latestBreakEnd! {
                    latestBreakEnd = breakEnd
                }
            }

            guard let breakEnd = latestBreakEnd else { return false }

            // Check if the desktop break ended within the minimum interval
            let minInterval = SettingsManager.shared.effectiveMinInterval * 60.0
            let timeSinceBreak = Date().timeIntervalSince(breakEnd)

            if timeSinceBreak < minInterval && timeSinceBreak >= 0 {
                // Also integrate the events while we're here
                pullAndIntegrate()
                return true
            }

            return false
        } catch {
            // Network error — don't block the trigger, just proceed
            return false
        }
    }

    // MARK: - Connectivity

    /// Explicitly check Supabase connectivity and update isSyncOnline
    func refreshConnectivityStatus() {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else {
            Task { @MainActor in isSyncOnline = false }
            return
        }
        Task {
            let online = await SupabaseClient.shared.checkConnectivity(syncKeyHash: syncKeyHash)
            await MainActor.run { isSyncOnline = online }
        }
    }

    // MARK: - Upload & Pending Queue

    /// Record a blackout event from this device (or watchOS relay) and upload to Supabase.
    /// If the upload fails, the event is queued for later retry.
    func recordEvent(
        startedAt: Date,
        duration: TimeInterval,
        completed: Bool,
        awareness: String?,
        source: String = "ios"
    ) {
        let formattedDate = SupabaseClient.formatDate(startedAt)
        recordEventRaw(
            startedAt: formattedDate,
            duration: duration,
            completed: completed,
            awareness: awareness,
            source: source
        )
    }

    /// Record a blackout event using a pre-formatted ISO 8601 date string.
    /// Use this when the same `started_at` must match an earlier upload (upsert).
    func recordEventRaw(
        startedAt: String,
        duration: TimeInterval,
        completed: Bool,
        awareness: String?,
        source: String = "ios"
    ) {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return }

        let event = PendingEvent(
            syncKey: syncKeyHash,
            startedAt: startedAt,
            duration: duration,
            completed: completed,
            awareness: awareness,
            source: source,
            queuedAt: Date()
        )

        Task {
            do {
                try await uploadPendingEvent(event)
                await MainActor.run { isSyncOnline = true }
            } catch {
                let status = (error as? SupabaseClient.SyncError).flatMap {
                    if case .httpError(let code) = $0 { return code }
                    return nil
                }
                print("Awareness Sync: upload failed (HTTP \(status ?? 0)), queuing — \(error.localizedDescription)")
                await MainActor.run { isSyncOnline = false }
                appendToPendingQueue(event)
            }
        }
    }

    /// Retry all pending events in the queue. Called on app launch and after each blackout.
    func flushPending() {
        var pending = loadPendingQueue()
        guard !pending.isEmpty else { return }

        let cutoff = Date().addingTimeInterval(-Double(maxPendingAgeDays * 86400))
        pending.removeAll { $0.queuedAt < cutoff }
        savePendingQueue(pending)

        guard !pending.isEmpty else { return }

        Task {
            var remaining: [PendingEvent] = []
            for event in pending {
                do {
                    try await uploadPendingEvent(event)
                } catch {
                    remaining.append(event)
                }
            }
            savePendingQueue(remaining)
        }
    }

    private func uploadPendingEvent(_ event: PendingEvent) async throws {
        let uploadEvent = SupabaseClient.UploadEvent(
            syncKey: event.syncKey,
            startedAt: event.startedAt,
            duration: event.duration,
            completed: event.completed,
            awareness: event.awareness,
            source: event.source
        )
        try await SupabaseClient.shared.uploadEvent(uploadEvent)
    }

    private func appendToPendingQueue(_ event: PendingEvent) {
        var queue = loadPendingQueue()
        queue.append(event)
        if queue.count > maxPendingEvents {
            queue = Array(queue.suffix(maxPendingEvents))
        }
        savePendingQueue(queue)
    }

    private func loadPendingQueue() -> [PendingEvent] {
        guard let data = defaults.data(forKey: pendingKey),
              let events = try? JSONDecoder().decode([PendingEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func savePendingQueue(_ events: [PendingEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    /// Queued event with metadata for retry logic
    private struct PendingEvent: Codable {
        let syncKey: String
        let startedAt: String
        let duration: Double
        let completed: Bool
        let awareness: String?
        let source: String
        let queuedAt: Date
    }

    // MARK: - Helpers

    /// Format a date as "yyyy-MM-dd" for ProgressTracker date keys
    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// Remove processed event IDs older than 90 days.
    /// Since we can't know event ages from IDs alone, we cap the set size instead.
    private func pruneProcessedIDs(_ ids: inout Set<String>) {
        let maxSize = 5000
        if ids.count > maxSize {
            // Keep the most recent entries by removing excess
            let excess = ids.count - maxSize
            for _ in 0..<excess {
                ids.remove(ids.first!)
            }
        }
    }

    private init() {}
}
