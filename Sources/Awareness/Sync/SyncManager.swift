import Foundation

/// Orchestrates uploading blackout events to Supabase from macOS.
/// Maintains a pending queue for offline resilience — events are retried on next launch
/// and after each successful blackout.
final class SyncManager {

    static let shared = SyncManager()

    private let defaults = UserDefaults.standard
    private let pendingKey = "syncPendingEvents"
    private let maxPendingEvents = 500
    private let maxPendingAgeDays = 7

    // MARK: - Record & Upload

    /// Record a completed blackout event and attempt to upload it to Supabase.
    /// If the upload fails, the event is queued for later retry.
    func recordEvent(
        startedAt: Date,
        duration: TimeInterval,
        completed: Bool,
        awareness: String?
    ) {
        let formattedDate = SupabaseClient.formatDate(startedAt)
        recordEventRaw(
            startedAt: formattedDate,
            duration: duration,
            completed: completed,
            awareness: awareness
        )
    }

    /// Record a blackout event using a pre-formatted ISO 8601 date string.
    /// Use this when the same `started_at` must match an earlier upload (upsert).
    func recordEventRaw(
        startedAt: String,
        duration: TimeInterval,
        completed: Bool,
        awareness: String?
    ) {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return }

        let event = PendingEvent(
            syncKey: syncKeyHash,
            startedAt: startedAt,
            duration: duration,
            completed: completed,
            awareness: awareness,
            source: "macos",
            queuedAt: Date()
        )

        // Try immediate upload, fall back to queue
        Task {
            do {
                try await uploadPendingEvent(event)
            } catch {
                print("Awareness Sync: upload failed, queuing — \(error.localizedDescription)")
                appendToPendingQueue(event)
            }
        }
    }

    /// Retry all pending events in the queue. Called on app launch and after each blackout.
    func flushPending() {
        var pending = loadPendingQueue()
        guard !pending.isEmpty else { return }

        // Prune events older than maxPendingAgeDays
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

    // MARK: - Private Helpers

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
        // Cap the queue size
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

    // MARK: - Pull Remote Events

    private var isPulling = false

    /// Pull events from other platforms and integrate them into local ProgressTracker.
    /// Deduplicates via processedEventIDs. Safe to call multiple times.
    func pullAndIntegrate() {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return }
        guard !isPulling else { return }
        isPulling = true

        Task {
            defer { isPulling = false }

            do {
                // Use lastPullDate or default to 30 days ago
                let since = SyncKeyManager.shared.lastPullDate
                    ?? Date().addingTimeInterval(-30 * 86400)

                let events = try await SupabaseClient.shared.fetchEvents(
                    syncKeyHash: syncKeyHash,
                    since: since,
                    excludeSource: "macos"
                )

                guard !events.isEmpty else { return }

                var processedIDs = SyncKeyManager.shared.processedEventIDs
                var latestCreatedAt: Date?

                for event in events {
                    // Deduplicate by event ID
                    let eventID: String
                    if let id = event.id {
                        eventID = String(id)
                    } else {
                        // Fallback: use started_at + source as dedup key
                        eventID = "\(event.startedAt)_\(event.source)"
                    }

                    guard !processedIDs.contains(eventID) else { continue }

                    // Parse the event date to determine which day record to update
                    guard let eventDate = SupabaseClient.parseDate(event.startedAt) else { continue }

                    // Parse awareness string to Int score (e.g. "75" → 75)
                    let awarenessScore: Int? = event.awareness.flatMap { Int($0) }

                    ProgressTracker.shared.integrateRemoteEvent(
                        date: eventDate,
                        completed: event.completed ?? false,
                        awarenessScore: awarenessScore
                    )

                    processedIDs.insert(eventID)

                    // Track the latest created_at for cursor update
                    if let createdAt = event.createdAt.flatMap({ SupabaseClient.parseDate($0) }) {
                        if latestCreatedAt == nil || createdAt > latestCreatedAt! {
                            latestCreatedAt = createdAt
                        }
                    }
                }

                // Persist dedup set and advance cursor
                SyncKeyManager.shared.processedEventIDs = processedIDs
                if let latest = latestCreatedAt {
                    SyncKeyManager.shared.lastPullDate = latest
                }

                print("Awareness Sync: pulled \(events.count) remote events")
            } catch {
                print("Awareness Sync: pull failed — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Pre-Trigger Check

    /// Quick check: was there a recent break on any other device that should prevent macOS
    /// from triggering? Checks iOS, Windows, and watchOS events.
    /// Returns true if macOS should NOT trigger (another device's break was recent).
    func shouldDeferToRecentBreak() async -> Bool {
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return false }

        do {
            let minInterval = SettingsManager.shared.minInterval * 60.0
            let since = Date().addingTimeInterval(-minInterval)
            let events = try await SupabaseClient.shared.fetchRecentEvents(
                syncKeyHash: syncKeyHash,
                since: since
            )

            guard !events.isEmpty else { return false }

            // Find the latest break end time
            var latestBreakEnd: Date?
            for event in events {
                guard let startedAt = SupabaseClient.parseDate(event.startedAt) else { continue }
                let breakEnd = startedAt.addingTimeInterval(event.duration)
                if latestBreakEnd == nil || breakEnd > latestBreakEnd! {
                    latestBreakEnd = breakEnd
                }
            }

            guard let breakEnd = latestBreakEnd else { return false }

            let timeSinceBreak = Date().timeIntervalSince(breakEnd)
            return timeSinceBreak < minInterval && timeSinceBreak >= 0
        } catch {
            // Network error — don't block the trigger, just proceed
            return false
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

    private init() {}
}
