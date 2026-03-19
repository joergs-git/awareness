using System.Text.Json;
using System.Text.Json.Serialization;

namespace Awareness.Sync;

/// <summary>
/// Orchestrates uploading blackout events to Supabase from Windows.
/// Maintains a pending queue for offline resilience — events are retried on next launch
/// and after each successful blackout.
/// </summary>
public class SyncManager
{
    public static SyncManager Shared { get; } = new();

    private static readonly string QueueFilePath =
        System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Awareness", "sync-queue.json");

    private const int MaxPendingEvents = 500;
    private const int MaxPendingAgeDays = 7;

    // MARK: - Record & Upload

    /// <summary>
    /// Record a completed blackout event and attempt to upload it to Supabase.
    /// If the upload fails, the event is queued for later retry.
    /// </summary>
    public void RecordEvent(DateTime startedAt, double duration, bool completed, string? awareness)
    {
        var formattedDate = SupabaseClient.FormatDate(startedAt);
        RecordEventRaw(formattedDate, duration, completed, awareness);
    }

    /// <summary>
    /// Record a blackout event using a pre-formatted ISO 8601 date string.
    /// Use this when the same started_at must match an earlier upload (upsert).
    /// </summary>
    public void RecordEventRaw(string startedAt, double duration, bool completed, string? awareness)
    {
        if (!SyncKeyManager.Shared.IsConfigured) return;
        var syncKeyHash = SyncKeyManager.Shared.HashedSyncKey;
        if (syncKeyHash == null) return;

        var ev = new PendingEvent
        {
            SyncKey = syncKeyHash,
            StartedAt = startedAt,
            Duration = duration,
            Completed = completed,
            Awareness = awareness,
            Source = "windows",
            QueuedAt = DateTime.UtcNow
        };

        _ = Task.Run(async () =>
        {
            try
            {
                await UploadPendingEventAsync(ev);
            }
            catch
            {
                AppendToPendingQueue(ev);
            }
        });
    }

    /// <summary>Retry all pending events in the queue. Called on app launch and after each blackout.</summary>
    public void FlushPending()
    {
        _ = Task.Run(async () =>
        {
            var pending = LoadPendingQueue();
            if (pending.Count == 0) return;

            // Prune events older than MaxPendingAgeDays
            var cutoff = DateTime.UtcNow.AddDays(-MaxPendingAgeDays);
            pending.RemoveAll(e => e.QueuedAt < cutoff);

            if (pending.Count == 0)
            {
                SavePendingQueue(pending);
                return;
            }

            var remaining = new List<PendingEvent>();
            foreach (var ev in pending)
            {
                try
                {
                    await UploadPendingEventAsync(ev);
                }
                catch
                {
                    remaining.Add(ev);
                }
            }

            SavePendingQueue(remaining);
        });
    }

    // MARK: - Private Helpers

    private static async Task UploadPendingEventAsync(PendingEvent ev)
    {
        var uploadEvent = new SupabaseClient.UploadEvent
        {
            SyncKey = ev.SyncKey,
            StartedAt = ev.StartedAt,
            Duration = ev.Duration,
            Completed = ev.Completed,
            Awareness = ev.Awareness,
            Source = ev.Source
        };
        await SupabaseClient.Shared.UploadEventAsync(uploadEvent);
    }

    private void AppendToPendingQueue(PendingEvent ev)
    {
        var queue = LoadPendingQueue();
        queue.Add(ev);
        if (queue.Count > MaxPendingEvents)
            queue.RemoveRange(0, queue.Count - MaxPendingEvents);
        SavePendingQueue(queue);
    }

    private static List<PendingEvent> LoadPendingQueue()
    {
        try
        {
            if (!File.Exists(QueueFilePath)) return new();
            var json = File.ReadAllText(QueueFilePath);
            return JsonSerializer.Deserialize<List<PendingEvent>>(json) ?? new();
        }
        catch { return new(); }
    }

    private static void SavePendingQueue(List<PendingEvent> events)
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(QueueFilePath)!;
            Directory.CreateDirectory(dir);
            var json = JsonSerializer.Serialize(events, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(QueueFilePath, json);
        }
        catch { /* best-effort */ }
    }

    // MARK: - Pull Remote Events

    private bool _isPulling;

    /// <summary>
    /// Pull events from other platforms and integrate them into local ProgressTracker.
    /// Deduplicates via ProcessedEventIDs. Safe to call multiple times.
    /// </summary>
    public void PullAndIntegrate()
    {
        if (!SyncKeyManager.Shared.IsConfigured) return;
        var syncKeyHash = SyncKeyManager.Shared.HashedSyncKey;
        if (syncKeyHash == null) return;
        if (_isPulling) return;
        _isPulling = true;

        _ = Task.Run(async () =>
        {
            try
            {
                // Use LastPullDate or default to 30 days ago
                var since = SyncKeyManager.Shared.LastPullDate
                    ?? DateTime.UtcNow.AddDays(-30);

                var events = await SupabaseClient.Shared.FetchEventsAsync(
                    syncKeyHash, since, "windows");

                if (events.Count == 0) return;

                var processedIDs = SyncKeyManager.Shared.ProcessedEventIDs;
                DateTime? latestCreatedAt = null;

                foreach (var ev in events)
                {
                    // Deduplicate by event ID
                    string eventID = ev.Id.HasValue
                        ? ev.Id.Value.ToString()
                        : $"{ev.StartedAt}_{ev.Source}";

                    if (processedIDs.Contains(eventID)) continue;

                    // Parse the event date
                    var eventDate = SupabaseClient.ParseDate(ev.StartedAt);
                    if (eventDate == null) continue;

                    // Parse awareness string to int score
                    int? awarenessScore = int.TryParse(ev.Awareness, out var score) ? score : null;

                    // Dispatch to UI thread for ProgressTracker (INotifyPropertyChanged)
                    System.Windows.Application.Current?.Dispatcher.Invoke(() =>
                    {
                        Progress.ProgressTracker.Shared.IntegrateRemoteEvent(
                            eventDate.Value, ev.Completed ?? false, awarenessScore);
                    });

                    processedIDs.Add(eventID);

                    // Track the latest created_at for cursor update
                    if (ev.CreatedAt != null)
                    {
                        var createdAt = SupabaseClient.ParseDate(ev.CreatedAt);
                        if (createdAt != null && (latestCreatedAt == null || createdAt > latestCreatedAt))
                            latestCreatedAt = createdAt;
                    }
                }

                // Persist dedup set and advance cursor
                SyncKeyManager.Shared.ProcessedEventIDs = processedIDs;
                if (latestCreatedAt.HasValue)
                    SyncKeyManager.Shared.LastPullDate = latestCreatedAt.Value;

                System.Diagnostics.Debug.WriteLine($"Awareness Sync: pulled {events.Count} remote events");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Awareness Sync: pull failed — {ex.Message}");
            }
            finally
            {
                _isPulling = false;
            }
        });
    }

    // MARK: - Pre-Trigger Check

    /// <summary>
    /// Quick check: was there a recent break on any other device that should prevent Windows
    /// from triggering? Checks macOS, iOS, and watchOS events.
    /// Returns true if Windows should NOT trigger (another device's break was recent).
    /// </summary>
    public async Task<bool> ShouldDeferToRecentBreakAsync()
    {
        if (!SyncKeyManager.Shared.IsConfigured) return false;
        var syncKeyHash = SyncKeyManager.Shared.HashedSyncKey;
        if (syncKeyHash == null) return false;

        try
        {
            var minInterval = Settings.SettingsManager.Shared.MinInterval;
            var since = DateTime.UtcNow.AddMinutes(-minInterval);
            var events = await SupabaseClient.Shared.FetchRecentEventsAsync(syncKeyHash, since);

            if (events.Count == 0) return false;

            // Find the latest break end time
            DateTime? latestBreakEnd = null;
            foreach (var ev in events)
            {
                var startedAt = SupabaseClient.ParseDate(ev.StartedAt);
                if (startedAt == null) continue;

                var breakEnd = startedAt.Value.AddSeconds(ev.Duration);
                if (latestBreakEnd == null || breakEnd > latestBreakEnd)
                    latestBreakEnd = breakEnd;
            }

            if (latestBreakEnd == null) return false;

            var timeSinceBreak = DateTime.UtcNow - latestBreakEnd.Value;
            var minIntervalSpan = TimeSpan.FromMinutes(minInterval);

            return timeSinceBreak < minIntervalSpan && timeSinceBreak >= TimeSpan.Zero;
        }
        catch
        {
            // Network error — don't block the trigger, just proceed
            return false;
        }
    }

    private class PendingEvent
    {
        [JsonPropertyName("syncKey")]
        public string SyncKey { get; set; } = "";

        [JsonPropertyName("startedAt")]
        public string StartedAt { get; set; } = "";

        [JsonPropertyName("duration")]
        public double Duration { get; set; }

        [JsonPropertyName("completed")]
        public bool Completed { get; set; }

        [JsonPropertyName("awareness")]
        public string? Awareness { get; set; }

        [JsonPropertyName("source")]
        public string Source { get; set; } = "windows";

        [JsonPropertyName("queuedAt")]
        public DateTime QueuedAt { get; set; }
    }

    private SyncManager() { }
}
