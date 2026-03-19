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
        using var request = new HttpRequestMessage(HttpMethod.Post, $"{SupabaseUrl}/rest/v1/blackout_events?on_conflict=sync_key,started_at,source")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };

        request.Headers.Add("apikey", SupabaseAnonKey);
        request.Headers.Add("Authorization", $"Bearer {SupabaseAnonKey}");
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

        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Add("apikey", SupabaseAnonKey);
        request.Headers.Add("Authorization", $"Bearer {SupabaseAnonKey}");

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

        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Add("apikey", SupabaseAnonKey);
        request.Headers.Add("Authorization", $"Bearer {SupabaseAnonKey}");

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<List<RemoteEvent>>(json) ?? new();
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
