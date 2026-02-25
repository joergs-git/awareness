using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Awareness.Progress;

/// <summary>
/// A single day's blackout statistics.
/// </summary>
public class DayRecord
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("triggered")]
    public int Triggered { get; set; }

    [JsonPropertyName("completed")]
    public int Completed { get; set; }
}

/// <summary>
/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Persists to a JSON file in %APPDATA%\Awareness\progress.json with a rolling 14-day window.
/// </summary>
public class ProgressTracker : INotifyPropertyChanged
{
    public static ProgressTracker Shared { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    private static readonly string ProgressDirectory =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Awareness");

    private static readonly string ProgressFilePath =
        Path.Combine(ProgressDirectory, "progress.json");

    // MARK: - Backing Fields

    private int _lifetimeTriggered;
    private int _lifetimeCompleted;
    private List<DayRecord> _dailyRecords = new();

    // MARK: - Properties

    /// <summary>Total number of blackouts ever triggered</summary>
    public int LifetimeTriggered
    {
        get => _lifetimeTriggered;
        private set { SetField(ref _lifetimeTriggered, value); }
    }

    /// <summary>Total number of blackouts ever completed (full duration)</summary>
    public int LifetimeCompleted
    {
        get => _lifetimeCompleted;
        private set { SetField(ref _lifetimeCompleted, value); }
    }

    /// <summary>Daily records for the last 14 days</summary>
    public List<DayRecord> DailyRecords => _dailyRecords;

    // MARK: - Computed Properties

    /// <summary>Number of blackouts triggered today</summary>
    public int TodayTriggered =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.Triggered ?? 0;

    /// <summary>Number of blackouts completed today (full duration)</summary>
    public int TodayCompleted =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.Completed ?? 0;

    /// <summary>Lifetime success rate (0.0 to 1.0)</summary>
    public double SuccessRate =>
        _lifetimeTriggered > 0 ? (double)_lifetimeCompleted / _lifetimeTriggered : 0;

    /// <summary>Last 14 days of records, padded with zero-count days for missing dates</summary>
    public List<DayRecord> Last14Days
    {
        get
        {
            var today = DateTime.Today;
            var result = new List<DayRecord>();

            for (int offset = 13; offset >= 0; offset--)
            {
                var date = today.AddDays(-offset);
                var key = DateKey(date);
                var existing = _dailyRecords.FirstOrDefault(r => r.Date == key);
                result.Add(existing ?? new DayRecord { Date = key, Triggered = 0, Completed = 0 });
            }

            return result;
        }
    }

    // MARK: - Recording

    /// <summary>Record that a blackout was triggered (screen appeared)</summary>
    public void RecordTriggered()
    {
        LifetimeTriggered++;
        UpdateTodayRecord(r => r.Triggered++);
        Save();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayTriggered)));
    }

    /// <summary>Record that a blackout completed its full duration (auto-dismiss timer fired)</summary>
    public void RecordCompleted()
    {
        LifetimeCompleted++;
        UpdateTodayRecord(r => r.Completed++);
        Save();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayCompleted)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SuccessRate)));
    }

    // MARK: - Private Helpers

    /// <summary>Get or create today's record and apply a mutation</summary>
    private void UpdateTodayRecord(Action<DayRecord> mutation)
    {
        var key = TodayKey();
        var existing = _dailyRecords.FirstOrDefault(r => r.Date == key);
        if (existing != null)
        {
            mutation(existing);
        }
        else
        {
            var record = new DayRecord { Date = key, Triggered = 0, Completed = 0 };
            mutation(record);
            _dailyRecords.Add(record);
        }
        PruneOldRecords();
    }

    /// <summary>Remove records older than 14 days</summary>
    private void PruneOldRecords()
    {
        var cutoff = DateKey(DateTime.Today.AddDays(-14));
        _dailyRecords.RemoveAll(r => string.Compare(r.Date, cutoff, StringComparison.Ordinal) < 0);
    }

    /// <summary>Format today's date as "yyyy-MM-dd"</summary>
    private static string TodayKey() => DateKey(DateTime.Today);

    /// <summary>Format a date as "yyyy-MM-dd"</summary>
    private static string DateKey(DateTime date) => date.ToString("yyyy-MM-dd");

    // MARK: - Persistence

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(ProgressDirectory);

            var data = new ProgressData
            {
                LifetimeTriggered = _lifetimeTriggered,
                LifetimeCompleted = _lifetimeCompleted,
                DailyRecords = _dailyRecords
            };

            var options = new JsonSerializerOptions { WriteIndented = true };
            string json = JsonSerializer.Serialize(data, options);
            File.WriteAllText(ProgressFilePath, json);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: failed to save progress — {ex.Message}");
        }
    }

    private void Load()
    {
        if (!File.Exists(ProgressFilePath))
            return;

        try
        {
            string json = File.ReadAllText(ProgressFilePath);
            var data = JsonSerializer.Deserialize<ProgressData>(json);
            if (data == null) return;

            _lifetimeTriggered = data.LifetimeTriggered;
            _lifetimeCompleted = data.LifetimeCompleted;
            _dailyRecords = data.DailyRecords ?? new List<DayRecord>();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Awareness: failed to load progress — {ex.Message}");
        }
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

    // MARK: - Init

    private ProgressTracker()
    {
        Load();
        PruneOldRecords();
    }

    // MARK: - Serialization Model

    private class ProgressData
    {
        [JsonPropertyName("lifetimeTriggered")]
        public int LifetimeTriggered { get; set; }

        [JsonPropertyName("lifetimeCompleted")]
        public int LifetimeCompleted { get; set; }

        [JsonPropertyName("dailyRecords")]
        public List<DayRecord>? DailyRecords { get; set; }
    }
}
