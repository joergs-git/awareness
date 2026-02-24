using System.Runtime.InteropServices;
using System.Windows.Interop;
using Microsoft.Win32;
using Awareness.Interop;

namespace Awareness.Detection;

/// <summary>
/// Detects whether the system is in an idle state (sleeping, display off, screen locked,
/// or screensaver running). Uses Windows events to track these states and provides
/// callbacks for idle/active transitions.
/// Blackouts are pointless during these states — the user isn't looking at the screen.
/// </summary>
public class SystemStateDetector : IDisposable
{
    public static SystemStateDetector Shared { get; } = new();

    // MARK: - State Flags

    private bool _isSleeping;
    private bool _isDisplayOff;
    private bool _isScreenLocked;
    private bool _isScreensaverRunning;

    public bool IsSleeping => _isSleeping;
    public bool IsDisplayOff => _isDisplayOff;
    public bool IsScreenLocked => _isScreenLocked;
    public bool IsScreensaverRunning => _isScreensaverRunning;

    /// <summary>Returns true if ANY idle condition is active</summary>
    public bool IsSystemIdle()
    {
        return _isSleeping || _isDisplayOff || _isScreenLocked || _isScreensaverRunning;
    }

    // MARK: - Transition Callbacks

    /// <summary>Fires on transition from active to idle (at least one flag became true)</summary>
    public Action? OnSystemDidBecomeIdle { get; set; }

    /// <summary>Fires when all flags clear and the system returns to active use</summary>
    public Action? OnSystemDidBecomeActive { get; set; }

    // MARK: - Internal State

    private IntPtr _displayNotificationHandle = IntPtr.Zero;
    private HwndSource? _hwndSource;
    private System.Timers.Timer? _screensaverPollTimer;
    private bool _disposed;
    private bool _displayNotificationsRegistered;

    // MARK: - Init

    private SystemStateDetector()
    {
        // Subscribe to power mode changes (sleep/wake)
        SystemEvents.PowerModeChanged += OnPowerModeChanged;

        // Subscribe to session switch events (lock/unlock)
        SystemEvents.SessionSwitch += OnSessionSwitch;

        // Start polling for screensaver state (no event-based API available)
        StartScreensaverPolling();
    }

    /// <summary>
    /// Register for display power change notifications using a hidden message-only window.
    /// Must be called from the UI thread after the WPF application is running.
    /// Safe to call multiple times — only registers once.
    /// </summary>
    public void RegisterDisplayNotifications()
    {
        if (_displayNotificationsRegistered) return;
        _displayNotificationsRegistered = true;

        // Create a hidden window to receive WM_POWERBROADCAST messages
        var parameters = new HwndSourceParameters("AwarenessDisplayDetector")
        {
            Width = 0,
            Height = 0,
            // Message-only window: no visible UI, minimal overhead
            ParentWindow = new IntPtr(-3) // HWND_MESSAGE
        };

        _hwndSource = new HwndSource(parameters);
        _hwndSource.AddHook(WndProc);

        var guid = NativeMethods.GUID_CONSOLE_DISPLAY_STATE;
        _displayNotificationHandle = NativeMethods.RegisterPowerSettingNotification(
            _hwndSource.Handle, ref guid, NativeMethods.DEVICE_NOTIFY_WINDOW_HANDLE);
    }

    // MARK: - Power Mode (Sleep/Wake)

    private void OnPowerModeChanged(object sender, PowerModeChangedEventArgs e)
    {
        switch (e.Mode)
        {
            case PowerModes.Suspend:
                SetFlag(ref _isSleeping, true);
                break;
            case PowerModes.Resume:
                SetFlag(ref _isSleeping, false);
                break;
        }
    }

    // MARK: - Session Switch (Lock/Unlock)

    private void OnSessionSwitch(object sender, SessionSwitchEventArgs e)
    {
        switch (e.Reason)
        {
            case SessionSwitchReason.SessionLock:
                SetFlag(ref _isScreenLocked, true);
                break;
            case SessionSwitchReason.SessionUnlock:
                SetFlag(ref _isScreenLocked, false);
                break;
        }
    }

    // MARK: - Display Power Notifications

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WM_POWERBROADCAST && wParam.ToInt32() == NativeMethods.PBT_POWERSETTINGCHANGE)
        {
            var setting = Marshal.PtrToStructure<NativeMethods.POWERBROADCAST_SETTING>(lParam);
            if (setting.PowerSetting == NativeMethods.GUID_CONSOLE_DISPLAY_STATE)
            {
                // Data follows the struct: 0 = off, 1 = on, 2 = dimmed
                int dataOffset = Marshal.SizeOf<NativeMethods.POWERBROADCAST_SETTING>();
                byte displayState = Marshal.ReadByte(lParam, dataOffset);

                SetFlag(ref _isDisplayOff, displayState == 0);
            }
        }

        return IntPtr.Zero;
    }

    // MARK: - Screensaver Polling

    /// <summary>
    /// Poll for screensaver state every 5 seconds. There's no event-based API for this
    /// on Windows, so polling SystemParametersInfo(SPI_GETSCREENSAVERRUNNING) is the
    /// standard approach.
    /// </summary>
    private void StartScreensaverPolling()
    {
        _screensaverPollTimer = new System.Timers.Timer(5000) { AutoReset = true };
        _screensaverPollTimer.Elapsed += (_, _) =>
        {
            bool isRunning = false;
            NativeMethods.SystemParametersInfo(NativeMethods.SPI_GETSCREENSAVERRUNNING, 0, ref isRunning, 0);
            SetFlag(ref _isScreensaverRunning, isRunning);
        };
        _screensaverPollTimer.Start();
    }

    // MARK: - State Transition Logic

    /// <summary>
    /// Updates a flag and fires the appropriate callback on idle/active transitions.
    /// Thread-safe: dispatches callbacks to the UI thread.
    /// </summary>
    private void SetFlag(ref bool flag, bool value)
    {
        bool wasIdle = IsSystemIdle();
        flag = value;
        bool isIdle = IsSystemIdle();

        if (!wasIdle && isIdle)
        {
            System.Windows.Application.Current?.Dispatcher.BeginInvoke(() =>
                OnSystemDidBecomeIdle?.Invoke());
        }
        else if (wasIdle && !isIdle)
        {
            System.Windows.Application.Current?.Dispatcher.BeginInvoke(() =>
                OnSystemDidBecomeActive?.Invoke());
        }
    }

    // MARK: - Cleanup

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        SystemEvents.PowerModeChanged -= OnPowerModeChanged;
        SystemEvents.SessionSwitch -= OnSessionSwitch;

        _screensaverPollTimer?.Stop();
        _screensaverPollTimer?.Dispose();

        _hwndSource?.RemoveHook(WndProc);
        _hwndSource?.Dispose();

        if (_displayNotificationHandle != IntPtr.Zero)
        {
            NativeMethods.UnregisterPowerSettingNotification(_displayNotificationHandle);
            _displayNotificationHandle = IntPtr.Zero;
        }

        GC.SuppressFinalize(this);
    }

    ~SystemStateDetector()
    {
        Dispose();
    }
}
