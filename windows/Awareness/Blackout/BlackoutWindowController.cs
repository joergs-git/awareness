using System.Windows;
using System.Windows.Threading;
using Awareness.Audio;
using Awareness.Interop;
using Awareness.Models;
using Awareness.Progress;
using Awareness.Settings;
using Awareness.Sync;
using Microsoft.Win32;

namespace Awareness.Blackout;

/// <summary>
/// Creates and manages full-screen blackout overlay windows — one per connected display.
/// Supports three phases: confirmation → breathing → post-blackout (awareness check + practice card).
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

    // Phase state
    private bool _isInConfirmationPhase;
    private bool _isInPostBlackoutPhase;
    private bool _isInAwarenessCheckPhase;

    // Pending blackout parameters (stored during confirmation phase)
    private double _pendingDuration;
    private BlackoutVisualType _pendingVisualType;
    private string _pendingCustomText = "";
    private string _pendingImagePath = "";
    private string _pendingVideoPath = "";

    // Sync event tracking
    private DateTime? _syncEventStartTime;
    private double _syncEventDuration;
    private bool _syncEventCompleted;
    private string? _syncEventAwareness;

    /// <summary>Whether a blackout (or confirmation/post-blackout phase) is currently being displayed</summary>
    public bool IsActive => _windows.Count > 0;

    public BlackoutWindowController()
    {
        // Configure keyboard hook: ESC dismisses unless handcuffs mode is on
        _keyboardHook.OnKeyDown = OnKeyDownDuringBlackout;

        // Monitor hot-plug: update overlay windows when displays are connected/disconnected
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
    }

    // MARK: - Show / Dismiss

    /// <summary>
    /// Cover all screens with the blackout overlay for a given duration.
    /// If startclick confirmation is enabled, shows a "Ready to breathe?" prompt first.
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

        if (SettingsManager.Shared.StartclickConfirmation)
        {
            // Store params for after confirmation
            _pendingDuration = duration;
            _pendingVisualType = visualType;
            _pendingCustomText = customText;
            _pendingImagePath = imagePath;
            _pendingVideoPath = videoPath;

            ShowConfirmation();
        }
        else
        {
            ShowBlackout(duration, visualType, customText, imagePath, videoPath);
        }
    }

    // MARK: - Confirmation Phase

    /// <summary>
    /// Show the "Ready to breathe?" confirmation overlay on all screens.
    /// </summary>
    private void ShowConfirmation()
    {
        _isInConfirmationPhase = true;

        foreach (var screen in GetAllScreenBounds())
        {
            var window = new BlackoutOverlayWindow();
            var confirmation = new ConfirmationControl
            {
                OnConfirm = HandleConfirmYes,
                OnDecline = HandleConfirmNo
            };
            window.SetContent(confirmation);
            window.PositionOnScreen(screen);
            window.Show();
            window.FadeIn();
            _windows.Add(window);
        }

        if (_windows.Count > 0)
            _windows[0].Activate();

        // Install keyboard hook (ESC = decline)
        _keyboardHook.SuppressAll = true;
        _keyboardHook.Install();

        // Record triggered immediately (matches macOS behavior)
        ProgressTracker.Shared.RecordTriggered();
    }

    private void HandleConfirmYes()
    {
        _isInConfirmationPhase = false;

        // Track sync event from confirmation start
        _syncEventStartTime = DateTime.UtcNow;
        _syncEventDuration = _pendingDuration;
        _syncEventCompleted = false;
        _syncEventAwareness = null;

        // Upload immediately so iOS knows a desktop break just started
        UploadSyncEvent();

        // Close confirmation windows and show the actual blackout
        var oldWindows = new List<BlackoutOverlayWindow>(_windows);
        _windows.Clear();
        _keyboardHook.SuppressAll = false;
        _keyboardHook.Uninstall();

        foreach (var window in oldWindows)
        {
            window.FadeOut();
        }

        // Start the actual blackout
        ShowBlackout(_pendingDuration, _pendingVisualType, _pendingCustomText, _pendingImagePath, _pendingVideoPath);
    }

    private void HandleConfirmNo()
    {
        _isInConfirmationPhase = false;

        // Upload sync event for the declined confirmation (triggered but not completed)
        UploadSyncEvent();

        // Clean up — don't count as completed since the user declined
        _keyboardHook.SuppressAll = false;
        _keyboardHook.Uninstall();

        var windowsToClose = new List<BlackoutOverlayWindow>(_windows);
        _windows.Clear();

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

    // MARK: - Blackout Phase

    /// <summary>
    /// Start the actual blackout (after confirmation if enabled, or directly).
    /// </summary>
    private void ShowBlackout(
        double duration,
        BlackoutVisualType visualType,
        string customText,
        string imagePath,
        string videoPath)
    {
        // Track sync event for Supabase upload
        _syncEventStartTime = DateTime.UtcNow;
        _syncEventDuration = duration;
        _syncEventCompleted = false;
        _syncEventAwareness = null;

        // Upload immediately so iOS knows a desktop break just started
        UploadSyncEvent();

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

        // Record triggered (only if no startclick — startclick records in ShowConfirmation)
        if (!SettingsManager.Shared.StartclickConfirmation)
            ProgressTracker.Shared.RecordTriggered();

        // Schedule automatic dismissal after the configured duration
        _dismissTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(duration)
        };
        _dismissTimer.Tick += (_, _) =>
        {
            _dismissTimer?.Stop();
            ProgressTracker.Shared.RecordCompleted();
            _syncEventCompleted = true;
            BeginPostBlackoutPhase();
        };
        _dismissTimer.Start();
    }

    // MARK: - Post-Blackout Phase

    /// <summary>
    /// Transition from the breathing phase to the post-blackout awareness check.
    /// </summary>
    private void BeginPostBlackoutPhase()
    {
        _isInPostBlackoutPhase = true;
        _isInAwarenessCheckPhase = true;

        // Play end gong at the breathing → awareness transition
        GongPlayer.Shared.PlayEndIfEnabled();

        // Get today's practice card and micro-task for the card phase
        var card = SettingsManager.Shared.TodaysPracticeCard();
        var task = SettingsManager.Shared.CurrentMicroTask();

        // Create the post-blackout control and swap it into all windows
        var postBlackout = new PostBlackoutControl();
        postBlackout.OnAwarenessAnswered = response =>
        {
            _isInAwarenessCheckPhase = false;
            ProgressTracker.Shared.RecordAwarenessResponse(response);

            // Capture awareness for sync upload
            _syncEventAwareness = response switch
            {
                AwarenessResponse.Yes => "yes",
                AwarenessResponse.Somewhat => "somewhat",
                AwarenessResponse.No => "no",
                _ => null
            };

            if (card != null)
            {
                // Show practice card phase
                postBlackout.ShowPracticeCard(
                    card.LocalizedTitle,
                    task?.LocalizedText);
            }
            else
            {
                // No card — dismiss directly
                Dismiss(silent: true);
            }
        };
        postBlackout.OnDismissRequested = () =>
        {
            // Upload sync event before dismissing (full lifecycle complete)
            UploadSyncEvent();
            // Rotate micro-task after dismissal
            SettingsManager.Shared.RotateMicroTask();
            Dismiss(silent: true);
        };

        // Swap content on all overlay windows
        foreach (var window in _windows)
        {
            window.SetContent(postBlackout);
        }

        // Show the awareness check
        postBlackout.ShowAwarenessCheck();
    }

    // MARK: - Dismiss

    /// <summary>
    /// Fade out and close all overlay windows, optionally playing the end gong.
    /// Pass silent=true when dismissing due to system idle (sleep/lock/screensaver)
    /// or when coming from the post-blackout phase (gong already played).
    /// </summary>
    public void Dismiss(bool silent = false)
    {
        // Upload sync event if not already uploaded (early dismiss, system idle, etc.)
        UploadSyncEvent();

        _dismissTimer?.Stop();
        _dismissTimer = null;
        _isInConfirmationPhase = false;
        _isInPostBlackoutPhase = false;
        _isInAwarenessCheckPhase = false;

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
    /// Phase-aware: during confirmation, ESC = decline. During awareness check, swallow all.
    /// During practice card phase, any key = dismiss. During breathing, ESC = dismiss.
    /// </summary>
    private bool OnKeyDownDuringBlackout(int vkCode)
    {
        if (!IsActive) return false;

        // Confirmation phase: ESC = decline, everything else suppressed
        if (_isInConfirmationPhase)
        {
            if (vkCode == NativeMethods.VK_ESCAPE)
            {
                Application.Current?.Dispatcher.BeginInvoke(HandleConfirmNo);
                return true;
            }
            return true;
        }

        // Post-blackout awareness check phase: swallow everything (let WPF buttons handle clicks)
        if (_isInAwarenessCheckPhase)
            return true;

        // Post-blackout practice card phase: any key dismisses
        if (_isInPostBlackoutPhase)
        {
            Application.Current?.Dispatcher.BeginInvoke(() =>
            {
                SettingsManager.Shared.RotateMicroTask();
                Dismiss(silent: true);
            });
            return true;
        }

        // Breathing phase: handcuffs mode swallows everything
        if (SettingsManager.Shared.HandcuffsMode)
            return true;

        // ESC dismisses the blackout early
        if (vkCode == NativeMethods.VK_ESCAPE)
        {
            Application.Current?.Dispatcher.BeginInvoke(() => Dismiss());
            return true;
        }

        return true; // swallow all other keys during blackout
    }

    // MARK: - Sync Upload

    /// <summary>
    /// Upload the current blackout event to Supabase. Called once per blackout lifecycle.
    /// Called at blackout START (completed=false) and again at END (completed=true).
    /// The upsert (merge-duplicates) updates the row with the final data on the second call.
    /// </summary>
    private void UploadSyncEvent()
    {
        if (_syncEventStartTime == null) return;

        SyncManager.Shared.RecordEvent(
            _syncEventStartTime.Value,
            _syncEventDuration,
            _syncEventCompleted,
            _syncEventAwareness);

        // Also flush any pending events from previous failed uploads
        SyncManager.Shared.FlushPending();
    }

    // MARK: - Monitor Hot-Plug

    /// <summary>
    /// Handle display configuration changes during an active blackout.
    /// Adds/removes overlay windows to match the current set of connected screens.
    /// </summary>
    private void OnDisplaySettingsChanged(object? sender, EventArgs e)
    {
        if (!IsActive || _isInConfirmationPhase || _isInPostBlackoutPhase) return;

        Application.Current?.Dispatcher.BeginInvoke(() =>
        {
            var currentBounds = GetAllScreenBounds();

            // If screen count changed, rebuild the overlay set
            if (currentBounds.Count != _windows.Count)
            {
                // Save visual config from the first window (they all show the same thing)
                // Close excess windows or add new ones
                var settings = SettingsManager.Shared;

                // Remove all existing and recreate
                foreach (var window in _windows)
                    window.Close();
                _windows.Clear();

                foreach (var screen in currentBounds)
                {
                    var window = new BlackoutOverlayWindow();
                    window.Configure(
                        settings.VisualType,
                        settings.ResolvedBreathingText(),
                        settings.CustomImagePath,
                        settings.CustomVideoPath);
                    window.PositionOnScreen(screen);
                    window.Show();
                    // Set opacity directly (no fade-in — we're mid-blackout)
                    window.Opacity = 1;
                    _windows.Add(window);
                }

                if (_windows.Count > 0)
                    _windows[0].Activate();
            }
        });
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
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;

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
