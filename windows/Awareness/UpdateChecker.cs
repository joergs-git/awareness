using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Awareness;

/// <summary>
/// Checks GitHub for a newer release of Awareness.
/// Queries the GitHub API once on startup and exposes the result
/// so the tray menu can show an "Update Available" item.
/// </summary>
public class UpdateChecker
{
    public static readonly UpdateChecker Shared = new();

    /// <summary>Whether a newer version is available on GitHub</summary>
    public bool UpdateAvailable { get; private set; }

    /// <summary>The latest version string from GitHub (e.g. "1.1"), null if not yet checked or check failed</summary>
    public string? LatestVersion { get; private set; }

    /// <summary>URL to the latest release page</summary>
    public const string ReleaseUrl = "https://github.com/joergs-git/awareness/releases/latest";

    private const string ApiUrl = "https://api.github.com/repos/joergs-git/awareness/releases/latest";

    private UpdateChecker() { }

    /// <summary>
    /// Fetch the latest release tag from GitHub and compare against the running version.
    /// Runs asynchronously; silently ignores any errors.
    /// </summary>
    public async Task CheckAsync()
    {
        try
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("Awareness", "1.0"));
            client.Timeout = TimeSpan.FromSeconds(10);

            var response = await client.GetAsync(ApiUrl);
            if (!response.IsSuccessStatusCode) return;

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);

            if (!doc.RootElement.TryGetProperty("tag_name", out var tagElement)) return;
            var tagName = tagElement.GetString();
            if (string.IsNullOrEmpty(tagName)) return;

            var remoteVersion = tagName.StartsWith('v') ? tagName[1..] : tagName;
            var localVersion = typeof(App).Assembly.GetName().Version?.ToString(2) ?? "0.0";

            if (IsVersionNewer(remoteVersion, localVersion))
            {
                LatestVersion = remoteVersion;
                UpdateAvailable = true;
            }
        }
        catch
        {
            // Silently ignore — no network, bad response, etc.
        }
    }

    /// <summary>
    /// Compare two dotted version strings numerically (e.g. "1.2" > "1.0", "2.0" > "1.9.9")
    /// </summary>
    internal static bool IsVersionNewer(string remote, string local)
    {
        var partsA = remote.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();
        var partsB = local.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();
        int count = Math.Max(partsA.Length, partsB.Length);

        for (int i = 0; i < count; i++)
        {
            int va = i < partsA.Length ? partsA[i] : 0;
            int vb = i < partsB.Length ? partsB[i] : 0;
            if (va > vb) return true;
            if (va < vb) return false;
        }

        return false;
    }
}
