using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Awareness.Sync;

/// <summary>
/// Lightweight Supabase REST API client for Windows.
/// Uploads blackout events to Supabase via PostgREST. No third-party dependencies.
/// </summary>
public class SupabaseClient
{
    public static SupabaseClient Shared { get; } = new();

    // Supabase anon key is a public key by design — RLS policies protect the data.
    private const string SupabaseUrl = "https://dntkhnjmczkqluwgddir.supabase.co";
    private const string SupabaseAnonKey = "sb_publishable_Ncq1smqygsQIQg4kKe7NqA_IR4xg8Kb";

    private static readonly HttpClient _http = new();

    /// <summary>
    /// Request header carrying the caller's sync-key hash. Server-side RLS policies compare it
    /// against the row's sync_key (or the storage object's path prefix), so a client can only
    /// ever read and change its own data. Sent on every request, REST and Storage alike.
    /// </summary>
    private const string SyncKeyHeader = "x-sync-key";

    /// <summary>
    /// Build a request with the common Supabase headers (apikey, Authorization, x-sync-key).
    /// The sync-key hash defaults to the locally configured key; callers that already resolved
    /// it pass it explicitly. Without a configured key no x-sync-key header is sent.
    /// </summary>
    private static HttpRequestMessage MakeRequest(HttpMethod method, string url, string? syncKeyHash = null)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.Add("apikey", SupabaseAnonKey);
        request.Headers.Add("Authorization", $"Bearer {SupabaseAnonKey}");
        var hash = syncKeyHash ?? SyncKeyManager.Shared.HashedSyncKey;
        if (!string.IsNullOrEmpty(hash))
            request.Headers.Add(SyncKeyHeader, hash);
        return request;
    }

    /// <summary>Event payload for uploading to Supabase</summary>
    public class UploadEvent
    {
        [JsonPropertyName("sync_key")]
        public string SyncKey { get; set; } = "";

        [JsonPropertyName("started_at")]
        public string StartedAt { get; set; } = "";

        [JsonPropertyName("duration")]
        public double Duration { get; set; }

        [JsonPropertyName("completed")]
        public bool Completed { get; set; }

        [JsonPropertyName("awareness")]
        public string? Awareness { get; set; }

        [JsonPropertyName("source")]
        public string Source { get; set; } = "windows";
    }

    /// <summary>
    /// Upload a single blackout event to Supabase.
    /// Uses ON CONFLICT DO NOTHING for idempotent retries.
    /// </summary>
    public async Task UploadEventAsync(UploadEvent ev)
    {
        var json = JsonSerializer.Serialize(ev);
        // on_conflict enables upsert: INSERT or UPDATE when (sync_key, started_at, source) matches
        using var request = MakeRequest(HttpMethod.Post, $"{SupabaseUrl}/rest/v1/blackout_events?on_conflict=sync_key,started_at,source", ev.SyncKey);
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        request.Headers.Add("Prefer", "return=minimal");
        request.Headers.Add("Prefer", "resolution=merge-duplicates");

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
    }

    /// <summary>Event received from Supabase (used for pre-trigger check and pull sync)</summary>
    public class RemoteEvent
    {
        [JsonPropertyName("id")]
        public int? Id { get; set; }

        [JsonPropertyName("started_at")]
        public string StartedAt { get; set; } = "";

        [JsonPropertyName("duration")]
        public double Duration { get; set; }

        [JsonPropertyName("completed")]
        public bool? Completed { get; set; }

        [JsonPropertyName("awareness")]
        public string? Awareness { get; set; }

        [JsonPropertyName("source")]
        public string Source { get; set; } = "";

        [JsonPropertyName("created_at")]
        public string? CreatedAt { get; set; }
    }

    /// <summary>
    /// Fetch recent events from other platforms for the given sync key.
    /// Used to check if another device had a break recently, preventing double-triggering.
    /// </summary>
    public async Task<List<RemoteEvent>> FetchRecentEventsAsync(string syncKeyHash, DateTime since)
    {
        var iso = FormatDate(since);
        var url = $"{SupabaseUrl}/rest/v1/blackout_events"
            + $"?sync_key=eq.{syncKeyHash}"
            + "&source=neq.windows"
            + $"&started_at=gt.{iso}"
            + "&select=id,started_at,duration,completed,awareness,source,created_at"
            + "&order=started_at.desc"
            + "&limit=5";

        using var request = MakeRequest(HttpMethod.Get, url, syncKeyHash);

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<List<RemoteEvent>>(json) ?? new();
    }

    /// <summary>
    /// Fetch all events from other platforms since a given cursor date.
    /// Used to pull remote events into local ProgressTracker for unified stats.
    /// </summary>
    public async Task<List<RemoteEvent>> FetchEventsAsync(string syncKeyHash, DateTime since, string excludeSource)
    {
        var iso = FormatDate(since);
        var url = $"{SupabaseUrl}/rest/v1/blackout_events"
            + $"?sync_key=eq.{syncKeyHash}"
            + $"&source=neq.{excludeSource}"
            + $"&created_at=gt.{iso}"
            + "&select=id,started_at,duration,completed,awareness,source,created_at"
            + "&order=created_at.asc";

        using var request = MakeRequest(HttpMethod.Get, url, syncKeyHash);

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<List<RemoteEvent>>(json) ?? new();
    }

    // MARK: - Storage (card photos)
    // Opt-in card-photo sync. Objects live under "{sync_key_hash}/..." in a private bucket;
    // RLS restricts each anon client to its own prefix via the x-sync-key header (same trust
    // model as blackout_events).

    private const string CardBucket = "card-assets";

    /// <summary>A single object returned by the Storage list endpoint.</summary>
    public class StorageObject
    {
        [JsonPropertyName("name")] public string Name { get; set; } = "";
        [JsonPropertyName("metadata")] public StorageMeta? Metadata { get; set; }
    }

    public class StorageMeta
    {
        [JsonPropertyName("size")] public long? Size { get; set; }
    }

    /// <summary>Upload (upsert) raw bytes to the card-assets bucket at the given path.</summary>
    public async Task UploadStorageObjectAsync(string path, byte[] data, string contentType)
    {
        using var request = MakeRequest(HttpMethod.Post, $"{SupabaseUrl}/storage/v1/object/{CardBucket}/{path}");
        request.Content = new ByteArrayContent(data);
        request.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);
        request.Headers.Add("x-upsert", "true");

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
    }

    /// <summary>Download an object's bytes. Returns null when the object is absent (404).</summary>
    public async Task<byte[]?> DownloadStorageObjectAsync(string path)
    {
        using var request = MakeRequest(HttpMethod.Get, $"{SupabaseUrl}/storage/v1/object/{CardBucket}/{path}");

        var response = await _http.SendAsync(request);
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync();
    }

    /// <summary>List objects under a prefix (e.g. "{hash}/") in the card-assets bucket.</summary>
    public async Task<List<StorageObject>> ListStorageObjectsAsync(string prefix)
    {
        var body = JsonSerializer.Serialize(new { prefix, limit = 100 });
        using var request = MakeRequest(HttpMethod.Post, $"{SupabaseUrl}/storage/v1/object/list/{CardBucket}");
        request.Content = new StringContent(body, Encoding.UTF8, "application/json");

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<List<StorageObject>>(json) ?? new();
    }

    /// <summary>Format a DateTime as ISO 8601 with fractional seconds</summary>
    public static string FormatDate(DateTime date)
    {
        return date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
    }

    /// <summary>Parse an ISO 8601 date string to UTC DateTime</summary>
    public static DateTime? ParseDate(string iso)
    {
        if (DateTime.TryParse(iso, null, System.Globalization.DateTimeStyles.RoundtripKind, out var dt))
            return dt.ToUniversalTime();
        return null;
    }

    private SupabaseClient() { }
}
