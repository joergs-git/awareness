using System.ComponentModel;
using System.Windows.Threading;
using Awareness.Detection;
using Awareness.Settings;

namespace Awareness.Blackout;

/// <summary>
/// Schedules blackouts at random intervals within the configured range.
/// Respects the active time window and media usage detection.
/// Automatically reschedules when relevant settings change.
/// Mirrors the macOS BlackoutScheduler.
/// </summary>
public class BlackoutScheduler
{
    private readonly BlackoutWindowController _blackoutController;
    private readonly SettingsManager _settings;
    private DispatcherTimer? _timer;
    private bool _isRunning;

    /// <summary>Public read-only alias for menu state</summary>
    public bool IsCurrentlyRunning => _isRunning;

    /// <summary>The date when the next blackout is expected to fire</summary>
    public DateTime? NextBlackoutDate { get; private set; }

    /// <summary>Called whenever the next-blackout date changes (for tooltip/menu updates)</summary>
    public Action<DateTime?>? OnNextDateChanged { get; set; }

    // Debounce timer for settings changes
    private DispatcherTimer? _settingsDebounce;

    public BlackoutScheduler(BlackoutWindowController blackoutController, SettingsManager? settings = null)
    {
        _blackoutController = blackoutController;
        _settings = settings ?? SettingsManager.Shared;
        ObserveSettingsChanges();
    }

    // MARK: - Start / Stop

    public void Start()
    {
        if (_isRunning) return;
        _isRunning = true;
        ScheduleNext();
    }

    public void Stop()
    {
        _isRunning = false;
        _timer?.Stop();
        _timer = null;
        NextBlackoutDate = null;
        OnNextDateChanged?.Invoke(null);
    }

    // MARK: - Settings Observation

    /// <summary>
    /// Reschedule when the user changes the interval range so it takes effect immediately.
    /// Uses a 500ms debounce to avoid excessive rescheduling during slider drags.
    /// </summary>
    private void ObserveSettingsChanges()
    {
        _settings.PropertyChanged += OnSettingsChanged;
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(SettingsManager.MinInterval) or nameof(SettingsManager.MaxInterval))
        {
            if (!_isRunning) return;

            // Debounce: wait 500ms after the last change before rescheduling
            _settingsDebounce?.Stop();
            _settingsDebounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
            _settingsDebounce.Tick += (_, _) =>
            {
                _settingsDebounce.Stop();
                Reschedule();
            };
            _settingsDebounce.Start();
        }
    }

    /// <summary>
    /// Public entry point: reschedule with a fresh random delay if the scheduler is running.
    /// Called after system wakes from sleep/lock/screensaver so the next blackout is relative
    /// to the moment the user returned, not the stale pre-sleep schedule.
    /// </summary>
    public void RescheduleIfRunning()
    {
        if (!_isRunning) return;
        Reschedule();
    }

    /// <summary>Cancel the current timer and schedule a fresh one with updated settings</summary>
    private void Reschedule()
    {
        _timer?.Stop();
        _timer = null;
        ScheduleNext();
    }

    // MARK: - Scheduling Logic

    private void ScheduleNext()
    {
        if (!_isRunning) return;

        var delay = RandomDelay();
        NextBlackoutDate = DateTime.Now.Add(delay);
        OnNextDateChanged?.Invoke(NextBlackoutDate);

        _timer = new DispatcherTimer { Interval = delay };
        _timer.Tick += (_, _) =>
        {
            _timer?.Stop();
            TimerFired();
        };
        _timer.Start();
    }

    private void TimerFired()
    {
        if (!_isRunning) return;
        NextBlackoutDate = null;
        OnNextDateChanged?.Invoke(null);

        // Skip if currently snoozed
        if (_settings.IsSnoozed)
        {
            ScheduleNext();
            return;
        }

        // Check if we're within the active time window
        if (!_settings.ActiveTimeWindow.IsCurrentlyActive())
        {
            ScheduleNext();
            return;
        }

        // Skip if camera or microphone is actively in use
        if (MediaUsageDetector.Shared.IsMediaInUse())
        {
            ScheduleNext();
            return;
        }

        // Skip if system is idle (sleeping, display off, locked, or screensaver)
        if (SystemStateDetector.Shared.IsSystemIdle())
        {
            ScheduleNext();
            return;
        }

        // Trigger the blackout with all configured visual settings
        _blackoutController.Show(
            duration: _settings.BlackoutDuration,
            visualType: _settings.VisualType,
            customText: _settings.CustomText,
            imagePath: _settings.CustomImagePath,
            videoPath: _settings.CustomVideoPath,
            completion: () => ScheduleNext()
        );
    }

    /// <summary>
    /// Returns a random delay between the configured min and max intervals.
    /// </summary>
    private TimeSpan RandomDelay()
    {
        double minSeconds = _settings.MinInterval * 60.0;
        double maxSeconds = _settings.MaxInterval * 60.0;

        if (maxSeconds <= minSeconds)
            return TimeSpan.FromSeconds(minSeconds);

        double seconds = Random.Shared.NextDouble() * (maxSeconds - minSeconds) + minSeconds;
        return TimeSpan.FromSeconds(seconds);
    }
}
