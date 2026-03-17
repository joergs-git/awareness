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
        guard SyncKeyManager.shared.isConfigured,
              let syncKeyHash = SyncKeyManager.shared.hashedSyncKey else { return }

        let event = PendingEvent(
            syncKey: syncKeyHash,
            startedAt: SupabaseClient.formatDate(startedAt),
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
