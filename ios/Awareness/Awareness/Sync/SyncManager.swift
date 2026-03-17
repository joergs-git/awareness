import Foundation

/// Orchestrates pulling desktop blackout events from Supabase and integrating them
/// into the local ProgressTracker and HealthKit. One-way sync: desktop → Supabase → iOS.
final class SyncManager {

    static let shared = SyncManager()

    /// Prevents concurrent pull operations
    private var isPulling = false

    // MARK: - Pull & Integrate

    /// Fetch new desktop events from Supabase and integrate into local stats + HealthKit.
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
                let events = try await SupabaseClient.shared.fetchEvents(
                    syncKeyHash: syncKeyHash,
                    since: since
                )

                guard !events.isEmpty else { return }

                var processedIDs = SyncKeyManager.shared.processedEventIDs
                var latestDate: Date?
                var integrated = false

                for event in events {
                    // Skip already-processed events
                    guard !processedIDs.contains(event.id) else { continue }

                    // Parse the event timestamp for date key and HealthKit
                    guard let startedAt = SupabaseClient.parseDate(event.startedAt) else { continue }

                    // Convert to local date key for ProgressTracker daily records
                    let dateKey = Self.dateKey(for: startedAt)

                    // Map awareness string to enum
                    let awareness: AwarenessResponse? = {
                        switch event.awareness {
                        case "yes": return .yes
                        case "somewhat": return .somewhat
                        case "no": return .no
                        default: return nil
                        }
                    }()

                    // Integrate into ProgressTracker
                    ProgressTracker.shared.integrateRemoteEvent(
                        date: dateKey,
                        completed: event.completed,
                        awareness: awareness
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
            } catch {
                // Silently fail — best-effort sync, cursor ensures catch-up
                print("Awareness Sync: pull failed — \(error.localizedDescription)")
            }
        }
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
