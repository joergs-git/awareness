using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Awareness.Blackout;
using Awareness.Settings;
using Hardcodet.Wpf.TaskbarNotification;
using Microsoft.Win32;

namespace Awareness.MenuBar;

/// <summary>
/// Manages the system tray (notification area) icon and its context menu.
/// Windows equivalent of StatusBarController on macOS.
/// Uses Hardcodet.NotifyIcon.Wpf for the tray icon.
/// </summary>
public class TrayIconController : IDisposable
{
    private readonly TaskbarIcon _trayIcon;
    private readonly BlackoutWindowController _blackoutController;
    private readonly BlackoutScheduler _scheduler;
    private Settings.SettingsWindow? _settingsWindow;
    private readonly DispatcherTimer _tooltipTimer;
    private readonly DispatcherTimer _snoozeCheckTimer;
    private bool _disposed;

    /// <summary>Snooze durations offered in the menu (minutes). 0 = "Until I resume"</summary>
    private static readonly int[] SnoozeDurations = [10, 20, 30, 60, 120, 0];

    public TrayIconController(BlackoutWindowController blackoutController, BlackoutScheduler scheduler)
    {
        _blackoutController = blackoutController;
        _scheduler = scheduler;

        // Create the tray icon
        _trayIcon = new TaskbarIcon
        {
            Icon = LoadTrayIcon(),
            ToolTipText = "Awareness",
            ContextMenu = BuildMenu()
        };

        // Rebuild the menu every time it opens to show current state
        _trayIcon.TrayContextMenuOpen += (_, _) =>
        {
            _trayIcon.ContextMenu = BuildMenu();
        };

        // Update tooltip periodically (every 30 seconds)
        _tooltipTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
        _tooltipTimer.Tick += (_, _) => UpdateTooltip();
        _tooltipTimer.Start();

        // Check for snooze expiry every 15 seconds
        _snoozeCheckTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(15) };
        _snoozeCheckTimer.Tick += (_, _) => CheckSnoozeExpiry();
        _snoozeCheckTimer.Start();

        // Update tooltip when scheduler picks a new next-blackout time
        _scheduler.OnNextDateChanged = _ => UpdateTooltip();
    }

    // MARK: - Tray Icon

    private System.Drawing.Icon? LoadTrayIcon()
    {
        try
        {
            var uri = new Uri("pack://application:,,,/Resources/tray-icon.ico", UriKind.Absolute);
            var streamInfo = Application.GetResourceStream(uri);
            if (streamInfo != null)
                return new System.Drawing.Icon(streamInfo.Stream);
        }
        catch
        {
            // Fallback: use a default icon
        }

        return System.Drawing.SystemIcons.Application;
    }

    // MARK: - Tooltip

    private void UpdateTooltip()
    {
        var settings = SettingsManager.Shared;

        if (settings.IsSnoozed)
        {
            if (settings.SnoozeUntil.HasValue && settings.SnoozeUntil.Value < DateTime.MaxValue)
                _trayIcon.ToolTipText = $"Awareness — Snoozed until {settings.SnoozeUntil.Value:t}";
            else
                _trayIcon.ToolTipText = "Awareness — Snoozed indefinitely";
            return;
        }

        if (_scheduler.NextBlackoutDate.HasValue)
        {
            _trayIcon.ToolTipText = $"Awareness — Next in {FormatRemainingTime(_scheduler.NextBlackoutDate.Value)}";
            return;
        }

        _trayIcon.ToolTipText = "Awareness";
    }

    private static string FormatRemainingTime(DateTime date)
    {
        var remaining = date - DateTime.Now;
        if (remaining.TotalSeconds <= 0) return "now";

        int minutes = (int)remaining.TotalMinutes;
        int seconds = remaining.Seconds;

        return minutes > 0 ? $"{minutes}m {seconds}s" : $"{seconds}s";
    }

    // MARK: - Snooze Check

    private void CheckSnoozeExpiry()
    {
        var settings = SettingsManager.Shared;
        if (settings.SnoozeUntil.HasValue && DateTime.Now >= settings.SnoozeUntil.Value)
        {
            ResumeFromSnooze();
        }
    }

    // MARK: - Menu Construction

    private ContextMenu BuildMenu()
    {
        var menu = new ContextMenu();
        var settings = SettingsManager.Shared;

        // Status line at the top
        string statusText;
        if (settings.IsSnoozed)
        {
            statusText = settings.SnoozeUntil.HasValue && settings.SnoozeUntil.Value < DateTime.MaxValue
                ? $"Snoozed until {settings.SnoozeUntil.Value:t}"
                : "Snoozed indefinitely";
        }
        else if (_scheduler.NextBlackoutDate.HasValue)
        {
            statusText = $"Next blackout in {FormatRemainingTime(_scheduler.NextBlackoutDate.Value)}";
        }
        else
        {
            statusText = "Scheduling...";
        }

        var statusItem = new MenuItem { Header = statusText, IsEnabled = false };
        menu.Items.Add(statusItem);
        menu.Items.Add(new Separator());

        // Test Blackout
        var testItem = new MenuItem { Header = "Test Blackout" };
        testItem.Click += (_, _) => TestBlackout();
        menu.Items.Add(testItem);
        menu.Items.Add(new Separator());

        // Snooze / Resume
        if (settings.IsSnoozed || !_scheduler.IsCurrentlyRunning)
        {
            var resumeItem = new MenuItem { Header = "Resume" };
            resumeItem.Click += (_, _) => ResumeFromSnooze();
            menu.Items.Add(resumeItem);
        }
        else
        {
            var snoozeItem = new MenuItem { Header = "Snooze" };
            foreach (int minutes in SnoozeDurations)
            {
                string title;
                if (minutes == 0)
                    title = "Until I resume";
                else if (minutes >= 60)
                    title = $"{minutes / 60} hour{(minutes >= 120 ? "s" : "")}";
                else
                    title = $"{minutes} minutes";

                var subItem = new MenuItem { Header = title, Tag = minutes };
                subItem.Click += OnSnoozeSelected;
                snoozeItem.Items.Add(subItem);
            }
            menu.Items.Add(snoozeItem);
        }

        menu.Items.Add(new Separator());

        // Launch at Login
        var launchAtLogin = new MenuItem
        {
            Header = "Launch at Login",
            IsCheckable = true,
            IsChecked = IsLaunchAtLoginEnabled()
        };
        launchAtLogin.Click += (_, _) => ToggleLaunchAtLogin();
        menu.Items.Add(launchAtLogin);

        // Settings
        var settingsItem = new MenuItem { Header = "Settings..." };
        settingsItem.Click += (_, _) => OpenSettings();
        menu.Items.Add(settingsItem);
        menu.Items.Add(new Separator());

        // Help
        var helpItem = new MenuItem { Header = "How to Use..." };
        helpItem.Click += (_, _) => ShowHelp();
        menu.Items.Add(helpItem);

        // About
        var aboutItem = new MenuItem { Header = "About Awareness..." };
        aboutItem.Click += (_, _) => ShowAbout();
        menu.Items.Add(aboutItem);

        // Update Available (shown only when a newer release exists on GitHub)
        if (UpdateChecker.Shared.UpdateAvailable && UpdateChecker.Shared.LatestVersion != null)
        {
            var updateItem = new MenuItem
            {
                Header = $"Update Available (v{UpdateChecker.Shared.LatestVersion})"
            };
            updateItem.Click += (_, _) => OpenReleasePage();
            menu.Items.Add(updateItem);
        }

        menu.Items.Add(new Separator());

        // Quit
        var quitItem = new MenuItem { Header = "Quit Awareness" };
        quitItem.Click += (_, _) => Application.Current.Shutdown();
        menu.Items.Add(quitItem);

        return menu;
    }

    // MARK: - Launch at Login (Registry-based)

    private const string RunRegistryKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "Awareness";

    private static bool IsLaunchAtLoginEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunRegistryKey, false);
        return key?.GetValue(AppName) != null;
    }

    private static void ToggleLaunchAtLogin()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunRegistryKey, true);
        if (key == null) return;

        if (key.GetValue(AppName) != null)
        {
            key.DeleteValue(AppName, false);
        }
        else
        {
            string exePath = Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName ?? "";
            if (!string.IsNullOrEmpty(exePath))
                key.SetValue(AppName, $"\"{exePath}\"");
        }
    }

    // MARK: - Snooze Actions

    private void OnSnoozeSelected(object sender, RoutedEventArgs e)
    {
        if (sender is not MenuItem item || item.Tag is not int minutes) return;

        if (minutes == 0)
        {
            // Snooze indefinitely
            SettingsManager.Shared.SnoozeUntil = DateTime.MaxValue;
        }
        else
        {
            SettingsManager.Shared.SnoozeUntil = DateTime.Now.AddMinutes(minutes);
        }

        _scheduler.Stop();
        UpdateTooltip();
    }

    private void ResumeFromSnooze()
    {
        SettingsManager.Shared.SnoozeUntil = null;
        _scheduler.Start();
        UpdateTooltip();
    }

    // MARK: - Actions

    private void TestBlackout()
    {
        var settings = SettingsManager.Shared;
        _blackoutController.Show(
            duration: settings.BlackoutDuration,
            visualType: settings.VisualType,
            customText: settings.CustomText,
            imagePath: settings.CustomImagePath,
            videoPath: settings.CustomVideoPath);
    }

    private void OpenSettings()
    {
        if (_settingsWindow != null)
        {
            _settingsWindow.Activate();
            return;
        }

        _settingsWindow = new Settings.SettingsWindow();
        _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        _settingsWindow.Show();
    }

    private void ShowHelp()
    {
        MessageBox.Show(
            "Awareness runs quietly in your system tray (☯ icon).\n\n" +
            "How it works:\n" +
            "• At random intervals, your screen fades to black for a few seconds\n" +
            "• A gong sounds at the start and end of each blackout\n" +
            "• Use this pause to breathe, close your eyes, and reset\n\n" +
            "Controls:\n" +
            "• ESC — dismiss a blackout early (unless Handcuffs mode is on)\n" +
            "• Snooze — temporarily pause from the system tray\n" +
            "• Settings — configure timing, visuals, and sounds\n\n" +
            "The app detects active camera/microphone usage and will skip blackouts during video calls.",
            "How to Use Awareness",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    private static void OpenReleasePage()
    {
        Process.Start(new ProcessStartInfo(UpdateChecker.ReleaseUrl)
        {
            UseShellExecute = true
        });
    }

    private void ShowAbout()
    {
        var version = typeof(App).Assembly.GetName().Version?.ToString(2) ?? "?";
        var result = MessageBox.Show(
            "A mindfulness timer for your PC.\n" +
            "Randomly pauses your screen to help you breathe.\n\n" +
            "The goal of this app is to not need it anymore a little bit later.\n\n" +
            "by joergsflow\n" +
            $"Version {version}\n\n" +
            "github.com/joergs-git/awareness\n\n" +
            "Click OK to close, or Cancel to open GitHub.",
            "Awareness",
            MessageBoxButton.OKCancel,
            MessageBoxImage.Information);

        if (result == MessageBoxResult.Cancel)
        {
            Process.Start(new ProcessStartInfo("https://github.com/joergs-git/awareness")
            {
                UseShellExecute = true
            });
        }
    }

    // MARK: - Cleanup

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        _tooltipTimer.Stop();
        _snoozeCheckTimer.Stop();
        _trayIcon.Dispose();

        GC.SuppressFinalize(this);
    }

    ~TrayIconController()
    {
        Dispose();
    }
}
