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
        using var request = new HttpRequestMessage(HttpMethod.Post, $"{SupabaseUrl}/rest/v1/blackout_events")
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };

        request.Headers.Add("apikey", SupabaseAnonKey);
        request.Headers.Add("Authorization", $"Bearer {SupabaseAnonKey}");
        request.Headers.Add("Prefer", "return=minimal,resolution=ignore-duplicates");

        var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
    }

    /// <summary>Format a DateTime as ISO 8601 with fractional seconds</summary>
    public static string FormatDate(DateTime date)
    {
        return date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
    }

    private SupabaseClient() { }
}
