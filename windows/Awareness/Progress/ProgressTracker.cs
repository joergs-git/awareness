using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Awareness.Progress;

/// <summary>
/// A single day's blackout statistics and awareness scores.
/// </summary>
public class DayRecord
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = "";

    [JsonPropertyName("triggered")]
    public int Triggered { get; set; }

    [JsonPropertyName("completed")]
    public int Completed { get; set; }

    /// <summary>Individual 0–100 awareness scores for the day</summary>
    [JsonPropertyName("awarenessScores")]
    public List<int> AwarenessScores { get; set; } = new();

    /// <summary>Actual elapsed seconds per session (completed or interrupted)</summary>
    [JsonPropertyName("sessionDurations")]
    public List<double> SessionDurations { get; set; } = new();

    // Legacy fields for backward-compatible deserialization (not serialized)
    [JsonPropertyName("yes")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public int Yes { get; set; }

    [JsonPropertyName("somewhat")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public int Somewhat { get; set; }

    [JsonPropertyName("no")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public int No { get; set; }

    // Computed awareness stats
    [JsonIgnore]
    public double AwarenessAverage =>
        AwarenessScores.Count > 0 ? AwarenessScores.Average() : 0;

    [JsonIgnore]
    public double AwarenessMedian
    {
        get
        {
            if (AwarenessScores.Count == 0) return 0;
            var sorted = AwarenessScores.OrderBy(x => x).ToList();
            int count = sorted.Count;
            if (count % 2 == 0)
                return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0;
            else
                return sorted[count / 2];
        }
    }

    [JsonIgnore]
    public int AwarenessMin => AwarenessScores.Count > 0 ? AwarenessScores.Min() : 0;

    [JsonIgnore]
    public int AwarenessMax => AwarenessScores.Count > 0 ? AwarenessScores.Max() : 0;

    /// <summary>
    /// After deserialization, migrate old yes/somewhat/no fields into awarenessScores
    /// if the new array is empty.
    /// </summary>
    public void MigrateFromLegacy()
    {
        if (AwarenessScores.Count == 0 && (Yes > 0 || Somewhat > 0 || No > 0))
        {
            for (int i = 0; i < Yes; i++) AwarenessScores.Add(100);
            for (int i = 0; i < Somewhat; i++) AwarenessScores.Add(50);
            for (int i = 0; i < No; i++) AwarenessScores.Add(0);
        }
    }
}

/// <summary>
/// Tracks blackout progress statistics: triggered vs completed counts per day and lifetime.
/// Also tracks post-blackout awareness scores (0–100 continuous scale).
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
    private int _lifetimeAwarenessSum;
    private int _lifetimeAwarenessCount;
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

    /// <summary>Sum of all awareness scores (for lifetime average)</summary>
    public int LifetimeAwarenessSum
    {
        get => _lifetimeAwarenessSum;
        private set { SetField(ref _lifetimeAwarenessSum, value); }
    }

    /// <summary>Total number of awareness scores recorded</summary>
    public int LifetimeAwarenessCount
    {
        get => _lifetimeAwarenessCount;
        private set { SetField(ref _lifetimeAwarenessCount, value); }
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

    /// <summary>Today's awareness scores</summary>
    public List<int> TodayAwarenessScores =>
        _dailyRecords.FirstOrDefault(r => r.Date == TodayKey())?.AwarenessScores ?? new();

    /// <summary>Today's median awareness (0–100), or -1 if no scores</summary>
    public double TodayMedianAwareness
    {
        get
        {
            var record = _dailyRecords.FirstOrDefault(r => r.Date == TodayKey());
            if (record == null || record.AwarenessScores.Count == 0) return -1;
            return record.AwarenessMedian;
        }
    }

    /// <summary>Lifetime average awareness (0–100)</summary>
    public double LifetimeAwarenessAverage =>
        _lifetimeAwarenessCount > 0 ? (double)_lifetimeAwarenessSum / _lifetimeAwarenessCount : 0;

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

    /// <summary>Record the user's post-blackout awareness score (0–100)</summary>
    public void RecordAwarenessScore(int score)
    {
        int clamped = Math.Clamp(score, 0, 100);
        LifetimeAwarenessSum += clamped;
        LifetimeAwarenessCount++;
        UpdateTodayRecord(r => r.AwarenessScores.Add(clamped));
        Save();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayAwarenessScores)));
    }

    // MARK: - Session Duration

    /// <summary>Record the actual elapsed duration (seconds) of a breathing session.
    /// Called for both completed and early-dismissed sessions.</summary>
    public void RecordSessionDuration(double seconds)
    {
        if (seconds <= 0) return;
        UpdateTodayRecord(r => r.SessionDurations.Add(seconds));
        Save();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(DailyRecords)));
    }

    /// <summary>All session durations from the last 14 days, flattened chronologically.</summary>
    public List<double> RecentSessionDurations =>
        Last14Days.SelectMany(r => r.SessionDurations).ToList();

    // MARK: - Remote Event Integration

    /// <summary>
    /// Integrate a remote event (from another platform via Supabase) into local stats.
    /// Increments triggered count; if completed, also increments completed count.
    /// If an awareness score is provided, records it.
    /// </summary>
    public void IntegrateRemoteEvent(DateTime eventDate, bool completed, int? awarenessScore)
    {
        LifetimeTriggered++;
        UpdateRecord(eventDate, r => r.Triggered++);

        if (completed)
        {
            LifetimeCompleted++;
            UpdateRecord(eventDate, r => r.Completed++);
        }

        if (awarenessScore.HasValue)
        {
            int clamped = Math.Clamp(awarenessScore.Value, 0, 100);
            LifetimeAwarenessSum += clamped;
            LifetimeAwarenessCount++;
            UpdateRecord(eventDate, r => r.AwarenessScores.Add(clamped));
        }

        Save();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayTriggered)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TodayCompleted)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SuccessRate)));
    }

    /// <summary>Get or create the record for a specific date and apply a mutation</summary>
    private void UpdateRecord(DateTime date, Action<DayRecord> mutation)
    {
        var key = DateKey(date);
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
                LifetimeAwarenessSum = _lifetimeAwarenessSum,
                LifetimeAwarenessCount = _lifetimeAwarenessCount,
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

            // Migrate daily records from legacy yes/somewhat/no fields
            foreach (var record in _dailyRecords)
            {
                record.MigrateFromLegacy();
            }

            // Try new keys first, then migrate from old yes/somewhat/no
            if (data.LifetimeAwarenessCount > 0 || data.LifetimeAwarenessSum > 0)
            {
                _lifetimeAwarenessSum = data.LifetimeAwarenessSum;
                _lifetimeAwarenessCount = data.LifetimeAwarenessCount;
            }
            else
            {
                // Migrate from old keys
                int oldYes = data.LifetimeYes;
                int oldSomewhat = data.LifetimeSomewhat;
                int oldNo = data.LifetimeNo;
                if (oldYes > 0 || oldSomewhat > 0 || oldNo > 0)
                {
                    _lifetimeAwarenessSum = oldYes * 100 + oldSomewhat * 50;
                    _lifetimeAwarenessCount = oldYes + oldSomewhat + oldNo;
                }
            }
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

        [JsonPropertyName("lifetimeAwarenessSum")]
        public int LifetimeAwarenessSum { get; set; }

        [JsonPropertyName("lifetimeAwarenessCount")]
        public int LifetimeAwarenessCount { get; set; }

        // Legacy fields for migration from old format
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
