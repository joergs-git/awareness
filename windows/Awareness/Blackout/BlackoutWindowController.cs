using System.ComponentModel;
using System.Windows;
using System.Windows.Threading;
using Awareness.Audio;
using Awareness.Interop;
using Awareness.Models;
using Awareness.Settings;

namespace Awareness.Blackout;

/// <summary>
/// Creates and manages full-screen blackout overlay windows — one per connected display.
/// During a blackout, a low-level keyboard hook suppresses keyboard input.
/// Windows equivalent of BlackoutWindowController on macOS.
/// </summary>
public class BlackoutWindowController : IDisposable
{
    private readonly List<BlackoutOverlayWindow> _windows = new();
    private DispatcherTimer? _dismissTimer;
    private readonly LowLevelKeyboardHook _keyboardHook = new();
    private Action? _completionHandler;
    private bool _disposed;

    /// <summary>Whether a blackout is currently being displayed</summary>
    public bool IsActive => _windows.Count > 0;

    public BlackoutWindowController()
    {
        // Configure keyboard hook: ESC dismisses unless handcuffs mode is on
        _keyboardHook.OnKeyDown = OnKeyDownDuringBlackout;
    }

    // MARK: - Show / Dismiss

    /// <summary>
    /// Cover all screens with the blackout overlay for a given duration.
    /// </summary>
    public void Show(
        double duration,
        BlackoutVisualType visualType = BlackoutVisualType.PlainBlack,
        string customText = "",
        string imagePath = "",
        string videoPath = "",
        Action? completion = null)
    {
        if (IsActive) return;
        _completionHandler = completion;

        // Play start gong immediately (before fade begins)
        GongPlayer.Shared.PlayStartIfEnabled();

        // Create one overlay window per connected screen
        foreach (var screen in GetAllScreenBounds())
        {
            var window = new BlackoutOverlayWindow();
            window.Configure(visualType, customText, imagePath, videoPath);
            window.PositionOnScreen(screen);
            window.Show();
            window.FadeIn();
            _windows.Add(window);
        }

        // Activate the first window to pull focus
        if (_windows.Count > 0)
            _windows[0].Activate();

        // Prevent screen saver and display sleep during the blackout
        NativeMethods.SetThreadExecutionState(
            NativeMethods.ES_CONTINUOUS | NativeMethods.ES_SYSTEM_REQUIRED | NativeMethods.ES_DISPLAY_REQUIRED);

        // Install keyboard hook to suppress typing during blackout
        _keyboardHook.SuppressAll = true;
        _keyboardHook.Install();

        // Record that a blackout was triggered
        Progress.ProgressTracker.Shared.RecordTriggered();

        // Schedule automatic dismissal after the configured duration
        _dismissTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(duration)
        };
        _dismissTimer.Tick += (_, _) =>
        {
            Progress.ProgressTracker.Shared.RecordCompleted();
            Dismiss();
        };
        _dismissTimer.Start();
    }

    /// <summary>
    /// Fade out and close all overlay windows, optionally playing the end gong.
    /// Pass silent=true when dismissing due to system idle (sleep/lock/screensaver)
    /// to avoid playing sounds while the user isn't at the screen.
    /// </summary>
    public void Dismiss(bool silent = false)
    {
        _dismissTimer?.Stop();
        _dismissTimer = null;

        // Remove keyboard hook
        _keyboardHook.SuppressAll = false;
        _keyboardHook.Uninstall();

        // Restore normal sleep/screensaver behavior
        NativeMethods.SetThreadExecutionState(NativeMethods.ES_CONTINUOUS);

        // Play deeper end gong unless this is a silent dismiss
        if (!silent)
            GongPlayer.Shared.PlayEndIfEnabled();

        var windowsToClose = new List<BlackoutOverlayWindow>(_windows);
        _windows.Clear();

        if (windowsToClose.Count == 0)
        {
            InvokeCompletion();
            return;
        }

        // Fade out all windows, invoke completion after the first one finishes
        bool completionFired = false;
        foreach (var window in windowsToClose)
        {
            if (!completionFired)
            {
                completionFired = true;
                window.FadeOut(() => InvokeCompletion());
            }
            else
            {
                window.FadeOut();
            }
        }
    }

    private void InvokeCompletion()
    {
        var handler = _completionHandler;
        _completionHandler = null;
        handler?.Invoke();
    }

    // MARK: - Keyboard Hook

    /// <summary>
    /// Handle key-down events during blackout.
    /// Returns true to suppress (which is always the case when SuppressAll is true).
    /// ESC dismisses the blackout unless handcuffs mode is on.
    /// </summary>
    private bool OnKeyDownDuringBlackout(int vkCode)
    {
        if (!IsActive) return false;

        // In handcuffs mode, swallow everything — user cannot escape
        if (SettingsManager.Shared.HandcuffsMode)
            return true;

        // ESC dismisses the blackout early
        if (vkCode == NativeMethods.VK_ESCAPE)
        {
            // Dispatch to UI thread since the hook callback is on a different thread
            Application.Current?.Dispatcher.BeginInvoke(() => Dismiss());
            return true;
        }

        return true; // swallow all other keys during blackout
    }

    // MARK: - Screen Enumeration

    /// <summary>
    /// Get the bounds of all connected screens in WPF logical (DPI-independent) coordinates.
    /// Uses System.Windows.Forms.Screen for multi-monitor enumeration, then converts
    /// from physical pixels to WPF logical units using the system DPI.
    /// </summary>
    private static List<Rect> GetAllScreenBounds()
    {
        var bounds = new List<Rect>();

        // Get the DPI scale factor from the primary screen
        var dpiScale = GetDpiScale();

        foreach (var screen in System.Windows.Forms.Screen.AllScreens)
        {
            var b = screen.Bounds;
            bounds.Add(new Rect(
                b.X / dpiScale,
                b.Y / dpiScale,
                b.Width / dpiScale,
                b.Height / dpiScale));
        }

        return bounds;
    }

    /// <summary>
    /// Get the system DPI scale factor (1.0 = 96 DPI, 1.5 = 144 DPI, etc.)
    /// </summary>
    private static double GetDpiScale()
    {
        // Try to get DPI from an existing window (may be null in tray-only mode)
        var window = Application.Current?.MainWindow
            ?? Application.Current?.Windows.OfType<Window>().FirstOrDefault();

        if (window != null)
        {
            var source = PresentationSource.FromVisual(window);
            if (source?.CompositionTarget != null)
                return source.CompositionTarget.TransformToDevice.M11;
        }

        // Fallback: compare physical vs logical primary screen dimensions
        double logicalWidth = System.Windows.SystemParameters.PrimaryScreenWidth;
        if (logicalWidth > 0)
        {
            double physicalWidth = System.Windows.Forms.Screen.PrimaryScreen?.Bounds.Width ?? logicalWidth;
            return physicalWidth / logicalWidth;
        }

        return 1.0;
    }

    // MARK: - Cleanup

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        _dismissTimer?.Stop();
        _keyboardHook.Dispose();

        foreach (var window in _windows)
            window.Close();
        _windows.Clear();

        GC.SuppressFinalize(this);
    }

    ~BlackoutWindowController()
    {
        Dispose();
    }
}
