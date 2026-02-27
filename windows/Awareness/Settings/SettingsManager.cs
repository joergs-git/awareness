using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using Awareness.Models;

namespace Awareness.Settings;

/// <summary>
/// Central settings store backed by a JSON file in %APPDATA%\Awareness\settings.json.
/// Implements INotifyPropertyChanged so UI elements can react to changes.
/// Mirrors the macOS SettingsManager with identical defaults.
/// </summary>
public class SettingsManager : INotifyPropertyChanged
{
    public static SettingsManager Shared { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    private static readonly string SettingsDirectory =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Awareness");

    private static readonly string SettingsFilePath =
        Path.Combine(SettingsDirectory, "settings.json");

    // Debounce timer to avoid writing on every keystroke
    private System.Timers.Timer? _saveDebounce;

    // MARK: - Backing Fields

    private int _activeStartHour = 6;
    private int _activeEndHour = 20;
    private double _minBlackoutDuration = 20.0;
    private double _maxBlackoutDuration = 20.0;
    private double _minInterval = 15.0;   // minutes
    private double _maxInterval = 30.0;   // minutes
    private bool _startGongEnabled = true;
    private bool _endGongEnabled = true;
    private bool _handcuffsMode = false;
    private BlackoutVisualType _visualType = BlackoutVisualType.Text;
    private string _customText = "Breathe.";
    private string _customImagePath = "";
    private string _customVideoPath = "";
    private DateTime? _snoozeUntil = null;

    // MARK: - Properties

    /// <summary>Start hour of the active time window (0-23)</summary>
    public int ActiveStartHour
    {
        get => _activeStartHour;
        set { if (SetField(ref _activeStartHour, value)) ScheduleSave(); }
    }

    /// <summary>End hour of the active time window (0-23)</summary>
    public int ActiveEndHour
    {
        get => _activeEndHour;
        set { if (SetField(ref _activeEndHour, value)) ScheduleSave(); }
    }

    /// <summary>Minimum blackout duration (seconds)</summary>
    public double MinBlackoutDuration
    {
        get => _minBlackoutDuration;
        set
        {
            if (SetField(ref _minBlackoutDuration, value))
            {
                // Enforce: min cannot exceed max
                if (_minBlackoutDuration > _maxBlackoutDuration)
                    MaxBlackoutDuration = _minBlackoutDuration;
                ScheduleSave();
            }
        }
    }

    /// <summary>Maximum blackout duration (seconds)</summary>
    public double MaxBlackoutDuration
    {
        get => _maxBlackoutDuration;
        set
        {
            if (SetField(ref _maxBlackoutDuration, value))
            {
                // Enforce: max cannot be less than min
                if (_maxBlackoutDuration < _minBlackoutDuration)
                    MinBlackoutDuration = _maxBlackoutDuration;
                ScheduleSave();
            }
        }
    }

    /// <summary>Minimum delay between blackouts (minutes)</summary>
    public double MinInterval
    {
        get => _minInterval;
        set
        {
            if (SetField(ref _minInterval, value))
            {
                // Enforce: min cannot exceed max
                if (_minInterval > _maxInterval)
                    MaxInterval = _minInterval;
                ScheduleSave();
            }
        }
    }

    /// <summary>Maximum delay between blackouts (minutes)</summary>
    public double MaxInterval
    {
        get => _maxInterval;
        set
        {
            if (SetField(ref _maxInterval, value))
            {
                // Enforce: max cannot be less than min
                if (_maxInterval < _minInterval)
                    MinInterval = _maxInterval;
                ScheduleSave();
            }
        }
    }

    /// <summary>Whether to play the start gong when a blackout begins</summary>
    public bool StartGongEnabled
    {
        get => _startGongEnabled;
        set { if (SetField(ref _startGongEnabled, value)) ScheduleSave(); }
    }

    /// <summary>Whether to play the end gong when a blackout finishes</summary>
    public bool EndGongEnabled
    {
        get => _endGongEnabled;
        set { if (SetField(ref _endGongEnabled, value)) ScheduleSave(); }
    }

    /// <summary>When on, the user cannot dismiss the blackout early</summary>
    public bool HandcuffsMode
    {
        get => _handcuffsMode;
        set { if (SetField(ref _handcuffsMode, value)) ScheduleSave(); }
    }

    /// <summary>What visual to show during blackout</summary>
    public BlackoutVisualType VisualType
    {
        get => _visualType;
        set { if (SetField(ref _visualType, value)) ScheduleSave(); }
    }

    /// <summary>Custom text displayed during text-mode blackout</summary>
    public string CustomText
    {
        get => _customText;
        set { if (SetField(ref _customText, value)) ScheduleSave(); }
    }

    /// <summary>File path for custom image blackout</summary>
    public string CustomImagePath
    {
        get => _customImagePath;
        set { if (SetField(ref _customImagePath, value)) ScheduleSave(); }
    }

    /// <summary>File path for custom video blackout</summary>
    public string CustomVideoPath
    {
        get => _customVideoPath;
        set { if (SetField(ref _customVideoPath, value)) ScheduleSave(); }
    }

    /// <summary>Date until which the app is snoozed (null = not snoozed)</summary>
    public DateTime? SnoozeUntil
    {
        get => _snoozeUntil;
        set { if (SetField(ref _snoozeUntil, value)) ScheduleSave(); }
    }

    // MARK: - Computed Helpers

    /// <summary>The active time window as a TimeWindow model</summary>
    public TimeWindow ActiveTimeWindow => new(ActiveStartHour, ActiveEndHour);

    /// <summary>Whether the app is currently snoozed</summary>
    public bool IsSnoozed => SnoozeUntil.HasValue && DateTime.Now < SnoozeUntil.Value;

    /// <summary>
    /// Returns a random blackout duration between min and max (seconds).
    /// If both values are equal, returns the fixed duration.
    /// </summary>
    public double RandomBlackoutDuration()
    {
        if (_maxBlackoutDuration <= _minBlackoutDuration)
            return _minBlackoutDuration;
        return _minBlackoutDuration + Random.Shared.NextDouble() * (_maxBlackoutDuration - _minBlackoutDuration);
    }

    // MARK: - Init

    private SettingsManager()
    {
        Load();
    }

    // MARK: - Persistence

    /// <summary>
    /// Load settings from the JSON file, falling back to defaults if not found.
    /// </summary>
    private void Load()
    {
        if (!File.Exists(SettingsFilePath))
            return;

        try
        {
            string json = File.ReadAllText(SettingsFilePath);
            var data = JsonSerializer.Deserialize<SettingsData>(json);
            if (data == null) return;

            _activeStartHour = data.ActiveStartHour;
            _activeEndHour = data.ActiveEndHour;

            // Migrate: if JSON has old blackoutDuration but no min/max, map it
            if (data.MinBlackoutDuration == 0 && data.MaxBlackoutDuration == 0 && data.BlackoutDuration > 0)
            {
                _minBlackoutDuration = data.BlackoutDuration;
                _maxBlackoutDuration = data.BlackoutDuration;
            }
            else
            {
                _minBlackoutDuration = data.MinBlackoutDuration > 0 ? data.MinBlackoutDuration : 20.0;
                _maxBlackoutDuration = data.MaxBlackoutDuration > 0 ? data.MaxBlackoutDuration : 20.0;
            }

            _minInterval = data.MinInterval;
            _maxInterval = data.MaxInterval;
            _startGongEnabled = data.StartGongEnabled;
            _endGongEnabled = data.EndGongEnabled;
            _handcuffsMode = data.HandcuffsMode;
            _visualType = BlackoutVisualTypeExtensions.FromSerializedString(data.VisualType);
            _customText = data.CustomText ?? "Breathe.";
            _customImagePath = data.CustomImagePath ?? "";
            _customVideoPath = data.CustomVideoPath ?? "";
            _snoozeUntil = data.SnoozeUntil;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: failed to load settings — {ex.Message}");
        }
    }

    /// <summary>
    /// Save current settings to the JSON file.
    /// </summary>
    public void Save()
    {
        try
        {
            Directory.CreateDirectory(SettingsDirectory);

            var data = new SettingsData
            {
                ActiveStartHour = _activeStartHour,
                ActiveEndHour = _activeEndHour,
                MinBlackoutDuration = _minBlackoutDuration,
                MaxBlackoutDuration = _maxBlackoutDuration,
                MinInterval = _minInterval,
                MaxInterval = _maxInterval,
                StartGongEnabled = _startGongEnabled,
                EndGongEnabled = _endGongEnabled,
                HandcuffsMode = _handcuffsMode,
                VisualType = _visualType.ToSerializedString(),
                CustomText = _customText,
                CustomImagePath = _customImagePath,
                CustomVideoPath = _customVideoPath,
                SnoozeUntil = _snoozeUntil
            };

            var options = new JsonSerializerOptions { WriteIndented = true };
            string json = JsonSerializer.Serialize(data, options);
            File.WriteAllText(SettingsFilePath, json);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: failed to save settings — {ex.Message}");
        }
    }

    /// <summary>
    /// Schedule a debounced save so rapid property changes don't thrash the disk.
    /// </summary>
    private void ScheduleSave()
    {
        _saveDebounce?.Stop();
        _saveDebounce?.Dispose();
        _saveDebounce = new System.Timers.Timer(500) { AutoReset = false };
        _saveDebounce.Elapsed += (_, _) => Save();
        _saveDebounce.Start();
    }

    // MARK: - INotifyPropertyChanged

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }

    // MARK: - Serialization Model

    private class SettingsData
    {
        [JsonPropertyName("activeStartHour")]
        public int ActiveStartHour { get; set; } = 6;

        [JsonPropertyName("activeEndHour")]
        public int ActiveEndHour { get; set; } = 22;

        [JsonPropertyName("blackoutDuration")]
        public double BlackoutDuration { get; set; } = 0;

        [JsonPropertyName("minBlackoutDuration")]
        public double MinBlackoutDuration { get; set; } = 20.0;

        [JsonPropertyName("maxBlackoutDuration")]
        public double MaxBlackoutDuration { get; set; } = 40.0;

        [JsonPropertyName("minInterval")]
        public double MinInterval { get; set; } = 15.0;

        [JsonPropertyName("maxInterval")]
        public double MaxInterval { get; set; } = 30.0;

        [JsonPropertyName("startGongEnabled")]
        public bool StartGongEnabled { get; set; } = true;

        [JsonPropertyName("endGongEnabled")]
        public bool EndGongEnabled { get; set; } = true;

        [JsonPropertyName("handcuffsMode")]
        public bool HandcuffsMode { get; set; } = false;

        [JsonPropertyName("visualType")]
        public string VisualType { get; set; } = "text";

        [JsonPropertyName("customText")]
        public string? CustomText { get; set; } = "Breathe.";

        [JsonPropertyName("customImagePath")]
        public string? CustomImagePath { get; set; } = "";

        [JsonPropertyName("customVideoPath")]
        public string? CustomVideoPath { get; set; } = "";

        [JsonPropertyName("snoozeUntil")]
        public DateTime? SnoozeUntil { get; set; }
    }
}
