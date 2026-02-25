using NAudio.Wave;
using Awareness.Settings;

namespace Awareness.Audio;

/// <summary>
/// Plays bundled gong sounds for blackout start and end using NAudio.
/// The start gong is higher pitched, the end gong is deeper to signal "time's up".
/// Each playback creates a new WaveOutEvent so start and end sounds can overlap.
/// </summary>
public class GongPlayer
{
    public static GongPlayer Shared { get; } = new();

    private GongPlayer() { }

    /// <summary>Play the start gong if the start gong setting is enabled</summary>
    public void PlayStartIfEnabled()
    {
        if (!SettingsManager.Shared.StartGongEnabled) return;
        PlayStart();
    }

    /// <summary>Play the end gong if the end gong setting is enabled</summary>
    public void PlayEndIfEnabled()
    {
        if (!SettingsManager.Shared.EndGongEnabled) return;
        PlayEnd();
    }

    /// <summary>Play the higher-pitched start gong</summary>
    public void PlayStart()
    {
        PlayResource("awareness-gong.wav");
    }

    /// <summary>Play the deeper-pitched end gong</summary>
    public void PlayEnd()
    {
        PlayResource("awareness-gong-end.wav");
    }

    /// <summary>
    /// Play an embedded WAV resource. Each call creates a new WaveOutEvent
    /// so multiple sounds can play simultaneously (e.g. start/end gong overlap).
    /// The player self-disposes when playback completes.
    /// A 2-second fade-out is applied at the end for a smooth ending.
    /// </summary>
    private void PlayResource(string resourceName)
    {
        try
        {
            var uri = new Uri($"pack://application:,,,/Resources/{resourceName}", UriKind.Absolute);
            var streamInfo = System.Windows.Application.GetResourceStream(uri);
            if (streamInfo == null)
            {
                System.Diagnostics.Debug.WriteLine($"Awareness: gong sound '{resourceName}' not found in resources");
                return;
            }

            // Copy to MemoryStream because NAudio needs a seekable stream
            var memStream = new MemoryStream();
            streamInfo.Stream.CopyTo(memStream);
            memStream.Position = 0;

            var reader = new WaveFileReader(memStream);
            var waveOut = new WaveOutEvent();
            waveOut.Init(reader);

            // Schedule a 2-second fade-out near the end of the sound
            var duration = reader.TotalTime.TotalSeconds;
            var fadeDelay = Math.Max(0, duration - 2.0);
            System.Timers.Timer? fadeTimer = null;
            System.Timers.Timer? delayTimer = null;

            // Self-cleanup when playback finishes
            waveOut.PlaybackStopped += (_, _) =>
            {
                delayTimer?.Dispose();
                fadeTimer?.Dispose();
                waveOut.Dispose();
                reader.Dispose();
                memStream.Dispose();
            };

            waveOut.Play();

            // Start fade-out after delay — step volume down in 20 intervals over 2 seconds
            delayTimer = new System.Timers.Timer(fadeDelay * 1000);
            delayTimer.AutoReset = false;
            delayTimer.Elapsed += (_, _) =>
            {
                int steps = 0;
                fadeTimer = new System.Timers.Timer(100);
                fadeTimer.AutoReset = true;
                fadeTimer.Elapsed += (_, _) =>
                {
                    steps++;
                    var volume = Math.Max(0f, 1.0f - (steps / 20f));
                    try { waveOut.Volume = volume; } catch { /* already disposed */ }
                    if (steps >= 20) fadeTimer?.Stop();
                };
                fadeTimer.Start();
            };
            delayTimer.Start();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: failed to play sound — {ex.Message}");
        }
    }
}
