using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Awareness.Models;
using Awareness.Settings;

namespace Awareness.Sync;

/// <summary>
/// Syncs user card photos + manual card selection via Supabase Storage. Opt-in
/// (<see cref="SettingsManager.CardPhotoSyncEnabled"/>). Symmetric union model: every
/// device uploads its own photos (upsert, never deleting remote) and downloads the rest.
/// Uses the same sync key as event sync, so devices must be linked via the sync passphrase.
/// </summary>
public class CardAssetSync
{
    public static CardAssetSync Shared { get; } = new();
    private CardAssetSync() { }

    private bool _isPushing;
    private bool _isSyncing;

    private class Manifest
    {
        [JsonPropertyName("manualCardID")] public string? ManualCardID { get; set; }
    }

    /// <summary>Upload every local card photo (upsert) plus a manifest carrying the manual selection.</summary>
    public async Task PushIfEnabledAsync()
    {
        var settings = SettingsManager.Shared;
        var hash = SyncKeyManager.Shared.HashedSyncKey;
        if (!settings.CardPhotoSyncEnabled || string.IsNullOrEmpty(hash) || _isPushing) return;
        _isPushing = true;
        try
        {
            foreach (var card in PracticeCard.AllCards)
            {
                foreach (CardPhotoSide side in Enum.GetValues<CardPhotoSide>())
                {
                    if (!settings.HasCardPhoto(card.Id, side)) continue;
                    var bytes = File.ReadAllBytes(settings.CardPhotoPath(card.Id, side));
                    await SupabaseClient.Shared.UploadStorageObjectAsync(
                        $"{hash}/card-{card.Id}-{side.FileToken()}.png", bytes, "image/png");
                }
            }
            var manualId = settings.ManualCardSelectionEnabled ? settings.ManualCardID : "";
            var manifest = JsonSerializer.SerializeToUtf8Bytes(new Manifest { ManualCardID = manualId });
            await SupabaseClient.Shared.UploadStorageObjectAsync($"{hash}/manifest.json", manifest, "application/json");
        }
        catch
        {
            // Non-fatal — retry on next change/launch.
        }
        finally { _isPushing = false; }
    }

    /// <summary>Download card photos + manual selection from Supabase into the local store.</summary>
    public async Task PullIfEnabledAsync()
    {
        var settings = SettingsManager.Shared;
        var hash = SyncKeyManager.Shared.HashedSyncKey;
        if (!settings.CardPhotoSyncEnabled || string.IsNullOrEmpty(hash) || _isSyncing) return;
        _isSyncing = true;
        try
        {
            var objects = await SupabaseClient.Shared.ListStorageObjectsAsync($"{hash}/");
            foreach (var obj in objects)
            {
                if (!TryParse(obj.Name, out var cardId, out var side)) continue;
                var localPath = settings.CardPhotoPath(cardId, side);
                long? localSize = File.Exists(localPath) ? new FileInfo(localPath).Length : null;
                // Download when missing locally or the remote size differs (updated elsewhere).
                if (localSize == null || localSize != obj.Metadata?.Size)
                {
                    var data = await SupabaseClient.Shared.DownloadStorageObjectAsync($"{hash}/{obj.Name}");
                    if (data != null) settings.WriteCardPhoto(cardId, side, data);
                }
            }

            var mData = await SupabaseClient.Shared.DownloadStorageObjectAsync($"{hash}/manifest.json");
            if (mData != null)
            {
                var manifest = JsonSerializer.Deserialize<Manifest>(mData);
                if (!string.IsNullOrEmpty(manifest?.ManualCardID))
                {
                    settings.ManualCardSelectionEnabled = true;
                    settings.ManualCardID = manifest.ManualCardID;
                }
            }
        }
        catch
        {
            // Non-fatal — retry on next launch.
        }
        finally { _isSyncing = false; }
    }

    /// <summary>Parse "card-&lt;id&gt;-&lt;side&gt;.png" (id may contain hyphens) into (cardId, side).</summary>
    private static bool TryParse(string fileName, out string cardId, out CardPhotoSide side)
    {
        cardId = "";
        side = CardPhotoSide.Front;
        if (!fileName.StartsWith("card-") || !fileName.EndsWith(".png")) return false;
        var core = fileName.Substring("card-".Length, fileName.Length - "card-".Length - ".png".Length);
        if (core.EndsWith("-front")) { cardId = core[..^"-front".Length]; side = CardPhotoSide.Front; return true; }
        if (core.EndsWith("-back")) { cardId = core[..^"-back".Length]; side = CardPhotoSide.Back; return true; }
        return false;
    }
}
