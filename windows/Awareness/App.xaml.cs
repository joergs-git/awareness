using System.Windows;
using Awareness.Blackout;
using Awareness.Detection;
using Awareness.MenuBar;
using Awareness.Resources;
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

        // Catch unhandled exceptions so tray-only app doesn't die silently
        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show($"Unhandled error:\n\n{args.Exception}", "Atempause Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            if (args.ExceptionObject is Exception ex)
                MessageBox.Show($"Fatal error:\n\n{ex}", "Atempause Error",
                    MessageBoxButton.OK, MessageBoxImage.Error);
        };

        try
        {
            // Single instance enforcement
            _singleInstanceMutex = new Mutex(true, "Awareness-SingleInstance", out bool isNew);
            if (!isNew)
            {
                MessageBox.Show(Strings.AlreadyRunning,
                    Strings.Awareness, MessageBoxButton.OK, MessageBoxImage.Information);
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

            // Check for updates on GitHub (background, non-blocking)
            _ = UpdateChecker.Shared.CheckAsync();

            // Flush any pending sync events from previous sessions
            Sync.SyncManager.Shared.FlushPending();

            // Show a welcome message on first launch
            ShowWelcomeIfFirstLaunch();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Startup failed:\n\n{ex}", "Atempause Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown();
        }
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

        // When the user comes back, clear any active snooze and restart
        // (matches macOS behavior: snooze auto-clears on wake)
        detector.OnSystemDidBecomeActive = () =>
        {
            var settings = SettingsManager.Shared;
            if (settings.IsSnoozed || !(_scheduler?.IsCurrentlyRunning ?? false))
            {
                settings.SnoozeUntil = null;
                _scheduler?.Start();
                _trayIconController?.RefreshMenu();
            }
            else
            {
                _scheduler?.RescheduleIfRunning();
            }
        };
    }

    // MARK: - First Launch Welcome

    private void ShowWelcomeIfFirstLaunch()
    {
        // Use a simple file marker in the settings directory to track first launch
        string markerPath = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Awareness", ".launched");

        if (File.Exists(markerPath)) return;

        try
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(markerPath)!);
            File.WriteAllText(markerPath, "");
        }
        catch { /* ignore — worst case the welcome shows again */ }

        // Small delay so the tray icon is visible before the dialog appears
        Dispatcher.BeginInvoke(() =>
        {
            var owner = new Window { Width = 0, Height = 0, WindowStyle = WindowStyle.None,
                ShowInTaskbar = false, ShowActivated = true, Topmost = true };
            owner.Show();
            MessageBox.Show(owner,
                Strings.WelcomeText,
                Strings.WelcomeTitle,
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            owner.Close();
        }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
    }
}
