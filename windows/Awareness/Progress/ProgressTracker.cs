using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Awareness.Progress;

/// <summary>
/// Post-blackout awareness response: "Were you there?"
/// </summary>
public enum AwarenessResponse
{
    Yes,
    Somewhat,
    No
}

/// <summary>
/// A single day's blackout statistics and awareness responses.
/// </summary>
public class DayRecord
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("triggered")]
    public int Triggered { get; set; }

    [JsonPropertyName("completed")]
    public int Completed { get; set; }

    // Awareness response counters — default 0; old JSON files without these fields
    // will deserialize cleanly because System.Text.Json leaves missing properties at
    // their default values when JsonIgnoreCondition is not set to require them.

    [JsonPropertyName("yes")]
    public int Yes { get; set; }

    [JsonPropertyName("somewhat")]
    public int Somewhat { get; set; }

    [JsonPropertyName("no")]
    public int No { get; set; }
}

/// <summary>
/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Also tracks post-blackout awareness responses (yes/somewhat/no).
/// Persists to a JSON file in %APPDATA%\Awareness\progress.json with a rolling 14-day window.
/// </summary>
public class ProgressTracker : INotifyPropertyChanged
{
    public static ProgressTracker Shared { get; } = new();

    public event PropertyChangedEventHandler? PropertyChanged;

    private static readonly string ProgressDirectory =
        System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Awareness");

    private static readonly string ProgressFilePath =
        System.IO.Path.Combine(ProgressDirectory, "progress.json");

    // MARK: - Backing Fields

    private int _lifetimeTriggered;
    private int _lifetimeCompleted;
    private int _lifetimeYes;
    private int _lifetimeSomewhat;
    private int _lifetimeNo;
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

    /// <summary>Total "yes" awareness responses across all time</summary>
    public int LifetimeYes
    {
        get => _lifetimeYes;
        private set { SetField(ref _lifetimeYes, value); }
    }

    /// <summary>Total "somewhat" awareness responses across all time</summary>
    public int LifetimeSomewhat
    {
        get => _lifetimeSomewhat;
        private set { SetField(ref _lifetimeSomewhat, value); }
    }

    /// <summary>Total "no" awareness responses across all time</summary>
    public int LifetimeNo
    {
        get => _lifetimeNo;
        private set { SetField(ref _lifetimeNo, value); }
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

    /// <summary>Today's "yes" awareness responses</summary>
    public int TodayYes =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.Yes ?? 0;

    /// <summary>Today's "somewhat" awareness responses</summary>
    public int TodaySomewhat =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.Somewhat ?? 0;

    /// <summary>Today's "no" awareness responses</summary>
    public int TodayNo =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.No ?? 0;

    /// <summary>Today's success rate (0.0 to 1.0)</summary>
    public double TodayRate =>
        TodayTriggered > 0 ? (double)TodayCompleted / TodayTriggered : 0;

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

    /// <summary>Record the user's post-blackout awareness response</summary>
    public void RecordAwarenessResponse(AwarenessResponse response)
    {
        switch (response)
        {
            case AwarenessResponse.Yes:
                LifetimeYes++;
                UpdateTodayRecord(r => r.Yes++);
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayYes)));
                break;
            case AwarenessResponse.Somewhat:
                LifetimeSomewhat++;
                UpdateTodayRecord(r => r.Somewhat++);
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodaySomewhat)));
                break;
            case AwarenessResponse.No:
                LifetimeNo++;
                UpdateTodayRecord(r => r.No++);
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayNo)));
                break;
        }
        Save();
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
                LifetimeYes = _lifetimeYes,
                LifetimeSomewhat = _lifetimeSomewhat,
                LifetimeNo = _lifetimeNo,
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
            // Awareness response totals — default 0 for old files that lack these fields
            _lifetimeYes = data.LifetimeYes;
            _lifetimeSomewhat = data.LifetimeSomewhat;
            _lifetimeNo = data.LifetimeNo;
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

        // Awareness response totals — absent in old JSON files, deserialize as 0 by default
        [JsonPropertyName("lifetimeYes")]
        public int LifetimeYes { get; set; }

        [JsonPropertyName("lifetimeSomewhat")]
        public int LifetimeSomewhat { get; set; }

        [JsonPropertyName("lifetimeNo")]
        public int LifetimeNo { get; set; }

        [JsonPropertyName("dailyRecords")]
        public List<DayRecord>? DailyRecords { get; set; }
    }
}
