using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Awareness.Blackout;
using Awareness.Resources;
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
    private Progress.ProgressWindow? _progressWindow;
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
            ToolTipText = Strings.Awareness,
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
                _trayIcon.ToolTipText = string.Format(Strings.TooltipSnoozedUntil, settings.SnoozeUntil.Value.ToString("t"));
            else
                _trayIcon.ToolTipText = Strings.TooltipSnoozedIndefinitely;
            return;
        }

        if (_scheduler.NextBlackoutDate.HasValue)
        {
            _trayIcon.ToolTipText = string.Format(Strings.NextIn, FormatRemainingTime(_scheduler.NextBlackoutDate.Value));
            return;
        }

        _trayIcon.ToolTipText = Strings.Awareness;
    }

    private static string FormatRemainingTime(DateTime date)
    {
        var remaining = date - DateTime.Now;
        if (remaining.TotalSeconds <= 0) return Strings.Now;

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
                ? string.Format(Strings.SnoozedUntil, settings.SnoozeUntil.Value.ToString("t"))
                : Strings.SnoozedIndefinitely;
        }
        else if (_scheduler.NextBlackoutDate.HasValue)
        {
            statusText = string.Format(Strings.NextBlackoutIn, FormatRemainingTime(_scheduler.NextBlackoutDate.Value));
        }
        else
        {
            statusText = Strings.Scheduling;
        }

        var statusItem = new MenuItem { Header = statusText, IsEnabled = false };
        menu.Items.Add(statusItem);
        menu.Items.Add(new Separator());

        // Progress
        var progressItem = new MenuItem { Header = Strings.ProgressMenu };
        progressItem.Click += (_, _) => ShowProgress();
        menu.Items.Add(progressItem);
        menu.Items.Add(new Separator());

        // Snooze / Resume
        if (settings.IsSnoozed || !_scheduler.IsCurrentlyRunning)
        {
            var resumeItem = new MenuItem { Header = Strings.Resume };
            resumeItem.Click += (_, _) => ResumeFromSnooze();
            menu.Items.Add(resumeItem);
        }
        else
        {
            var snoozeItem = new MenuItem { Header = Strings.Snooze };
            foreach (int minutes in SnoozeDurations)
            {
                string title;
                if (minutes == 0)
                    title = Strings.UntilIResume;
                else if (minutes >= 60)
                    title = string.Format(minutes >= 120 ? Strings.HoursFormat : Strings.HourFormat, minutes / 60);
                else
                    title = string.Format(Strings.MinutesFormat, minutes);

                var subItem = new MenuItem { Header = title, Tag = minutes };
                subItem.Click += OnSnoozeSelected;
                snoozeItem.Items.Add(subItem);
            }
            menu.Items.Add(snoozeItem);
        }

        menu.Items.Add(new Separator());

        // Breathe now — manual blackout trigger
        var testItem = new MenuItem { Header = Strings.TestBlackout };
        testItem.Click += (_, _) => TestBlackout();
        menu.Items.Add(testItem);

        // Launch at Login
        var launchAtLogin = new MenuItem
        {
            Header = Strings.LaunchAtLogin,
            IsCheckable = true,
            IsChecked = IsLaunchAtLoginEnabled()
        };
        launchAtLogin.Click += (_, _) => ToggleLaunchAtLogin();
        menu.Items.Add(launchAtLogin);

        // Settings
        var settingsItem = new MenuItem { Header = Strings.SettingsMenu };
        settingsItem.Click += (_, _) => OpenSettings();
        menu.Items.Add(settingsItem);
        menu.Items.Add(new Separator());

        // Help
        var helpItem = new MenuItem { Header = Strings.HowToUseMenu };
        helpItem.Click += (_, _) => ShowHelp();
        menu.Items.Add(helpItem);

        // About
        var aboutItem = new MenuItem { Header = Strings.AboutMenu };
        aboutItem.Click += (_, _) => ShowAbout();
        menu.Items.Add(aboutItem);

        // Update Available (shown only when a newer release exists on GitHub)
        if (UpdateChecker.Shared.UpdateAvailable && UpdateChecker.Shared.LatestVersion != null)
        {
            var updateItem = new MenuItem
            {
                Header = string.Format(Strings.UpdateAvailable, UpdateChecker.Shared.LatestVersion)
            };
            updateItem.Click += (_, _) => OpenReleasePage();
            menu.Items.Add(updateItem);
        }

        menu.Items.Add(new Separator());

        // Quit
        var quitItem = new MenuItem { Header = Strings.QuitAwareness };
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
            duration: settings.RandomBlackoutDuration(),
            visualType: settings.VisualType,
            customText: settings.ResolvedBreathingText(),
            imagePath: settings.CustomImagePath,
            videoPath: settings.CustomVideoPath);
    }

    private void ShowProgress()
    {
        if (_progressWindow != null)
        {
            _progressWindow.Activate();
            return;
        }

        _progressWindow = new Progress.ProgressWindow();
        _progressWindow.Closed += (_, _) => _progressWindow = null;
        _progressWindow.Show();
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
            Strings.HowToUseText,
            Strings.HowToUseTitle,
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
            string.Format(Strings.AboutText, version),
            Strings.AboutTitle,
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
