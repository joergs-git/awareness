using Microsoft.Win32;
using NAudio.CoreAudioApi;

namespace Awareness.Detection;

/// <summary>
/// Detects whether the camera or microphone is actively in use by another application.
/// Uses the Windows registry CapabilityAccessManager for camera detection and
/// NAudio WASAPI session enumeration for microphone detection.
/// Skips blackouts when camera or mic is active (avoids interrupting calls/recordings).
/// </summary>
public class MediaUsageDetector
{
    public static MediaUsageDetector Shared { get; } = new();

    private MediaUsageDetector() { }

    /// <summary>Returns true if any camera or microphone is currently in use</summary>
    public bool IsMediaInUse()
    {
        return IsCameraInUse() || IsMicrophoneInUse();
    }

    // MARK: - Camera Detection

    /// <summary>
    /// Check if any camera is in use by examining the Windows CapabilityAccessManager registry.
    /// An app actively using the camera will have LastUsedTimeStop == 0 (still running).
    /// </summary>
    private bool IsCameraInUse()
    {
        try
        {
            const string basePath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam";

            // Check both HKLM and HKCU
            if (CheckCameraRegistry(Registry.LocalMachine, basePath)) return true;
            if (CheckCameraRegistry(Registry.CurrentUser, basePath)) return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: camera detection error — {ex.Message}");
        }

        return false;
    }

    private bool CheckCameraRegistry(RegistryKey root, string basePath)
    {
        using var baseKey = root.OpenSubKey(basePath);
        if (baseKey == null) return false;

        foreach (string subKeyName in baseKey.GetSubKeyNames())
        {
            using var appKey = baseKey.OpenSubKey(subKeyName);
            if (appKey == null) continue;

            // Direct app entries
            if (IsActiveTimestamp(appKey)) return true;

            // Non-packaged apps are nested one level deeper
            foreach (string nestedName in appKey.GetSubKeyNames())
            {
                using var nestedKey = appKey.OpenSubKey(nestedName);
                if (nestedKey != null && IsActiveTimestamp(nestedKey))
                    return true;
            }
        }

        return false;
    }

    /// <summary>
    /// An app is actively using the camera if LastUsedTimeStop is 0 (hasn't stopped yet).
    /// </summary>
    private bool IsActiveTimestamp(RegistryKey key)
    {
        var lastUsedTimeStop = key.GetValue("LastUsedTimeStop");
        if (lastUsedTimeStop is long stopTime)
            return stopTime == 0;
        return false;
    }

    // MARK: - Microphone Detection

    /// <summary>
    /// Check if any microphone is actively capturing audio using WASAPI session enumeration.
    /// Looks for active audio sessions on capture (input) devices.
    /// </summary>
    private bool IsMicrophoneInUse()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            var devices = enumerator.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active);

            foreach (var device in devices)
            {
                try
                {
                    // Check if the device has any active audio sessions
                    var sessionManager = device.AudioSessionManager;
                    var sessions = sessionManager.Sessions;

                    for (int i = 0; i < sessions.Count; i++)
                    {
                        var session = sessions[i];
                        if (session.State == NAudio.CoreAudioApi.Interfaces.AudioSessionState.AudioSessionStateActive)
                            return true;
                    }
                }
                catch
                {
                    // Skip devices that can't be queried
                }
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: microphone detection error — {ex.Message}");
        }

        return false;
    }
}
