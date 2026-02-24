using System.Windows;
using Awareness.Blackout;
using Awareness.Detection;
using Awareness.MenuBar;
using Awareness.Settings;

namespace Awareness;

/// <summary>
/// Application entry point. Wires together all components:
/// tray icon, blackout controller, scheduler, and system state detection.
/// Runs as a tray-only app (no main window) with single-instance enforcement.
/// </summary>
public partial class App : Application
{
    private static Mutex? _singleInstanceMutex;
    private TrayIconController? _trayIconController;
    private BlackoutWindowController? _blackoutController;
    private BlackoutScheduler? _scheduler;

    private const string HasLaunchedBeforeKey = "hasLaunchedBefore";

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Single instance enforcement
        _singleInstanceMutex = new Mutex(true, "Awareness-SingleInstance", out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("Awareness is already running in the system tray.",
                "Awareness", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        // Create core components
        _blackoutController = new BlackoutWindowController();
        _scheduler = new BlackoutScheduler(_blackoutController);
        _trayIconController = new TrayIconController(_blackoutController, _scheduler);

        // Auto-start the scheduler
        _scheduler.Start();

        // Pause blackouts when the system is idle (sleep, lock screen, screensaver)
        ConfigureSystemStateDetector();

        // Register for display power change notifications (requires UI thread)
        SystemStateDetector.Shared.RegisterDisplayNotifications();

        // Show a welcome message on first launch
        ShowWelcomeIfFirstLaunch();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _scheduler?.Stop();
        _trayIconController?.Dispose();
        _blackoutController?.Dispose();
        SystemStateDetector.Shared.Dispose();
        SettingsManager.Shared.Save();
        _singleInstanceMutex?.ReleaseMutex();
        _singleInstanceMutex?.Dispose();

        base.OnExit(e);
    }

    // MARK: - System State Detection

    /// <summary>
    /// Wire up idle/active callbacks so blackouts don't fire while the user is away.
    /// </summary>
    private void ConfigureSystemStateDetector()
    {
        var detector = SystemStateDetector.Shared;

        // When the system goes idle, silently dismiss any active blackout
        detector.OnSystemDidBecomeIdle = () =>
        {
            if (_blackoutController?.IsActive == true)
                _blackoutController.Dismiss(silent: true);
        };

        // When the user comes back, reschedule with a fresh random delay
        detector.OnSystemDidBecomeActive = () =>
        {
            _scheduler?.RescheduleIfRunning();
        };
    }

    // MARK: - First Launch Welcome

    private void ShowWelcomeIfFirstLaunch()
    {
        // Use a simple file marker in the settings directory to track first launch
        string markerPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Awareness", ".launched");

        if (File.Exists(markerPath)) return;

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(markerPath)!);
            File.WriteAllText(markerPath, "");
        }
        catch { /* ignore — worst case the welcome shows again */ }

        // Small delay so the tray icon is visible before the dialog appears
        Dispatcher.BeginInvoke(() =>
        {
            MessageBox.Show(
                "Awareness is now running in your system tray.\n\n" +
                "Look for the ☯ icon in the bottom-right of your screen. " +
                "Right-click it to access settings, snooze, or quit.\n\n" +
                "Your screen will randomly fade to black at gentle intervals — " +
                "a moment to pause, breathe, and return to the present.\n\n" +
                "You can configure everything from the tray icon → Settings.",
                "Welcome to Awareness",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
    }
}
