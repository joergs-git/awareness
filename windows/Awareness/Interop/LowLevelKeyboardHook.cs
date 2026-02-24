using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Awareness.Interop;

/// <summary>
/// Installs a WH_KEYBOARD_LL hook to suppress keyboard input during blackout.
/// Windows equivalent of CGEvent.tapCreate on macOS.
/// No special permissions required (unlike macOS Accessibility).
///
/// IMPORTANT: The callback must return quickly (&lt;300ms) or Windows will silently
/// remove the hook. Keep processing minimal.
/// </summary>
public class LowLevelKeyboardHook : IDisposable
{
    private IntPtr _hookHandle = IntPtr.Zero;
    private NativeMethods.LowLevelKeyboardProc? _hookProc;
    private bool _disposed;

    /// <summary>
    /// When true, all keyboard events are suppressed (swallowed).
    /// When false, events pass through normally.
    /// </summary>
    public bool SuppressAll { get; set; }

    /// <summary>
    /// Fired when a key-down event occurs while the hook is active.
    /// Return true to suppress (swallow) the key, false to pass through.
    /// If SuppressAll is true, this is still called but the key is suppressed regardless.
    /// </summary>
    public Func<int, bool>? OnKeyDown { get; set; }

    /// <summary>
    /// Install the keyboard hook. Call Dispose() or Uninstall() to remove it.
    /// </summary>
    public void Install()
    {
        if (_hookHandle != IntPtr.Zero)
            return;

        // Must hold a reference to the delegate to prevent GC collection
        _hookProc = HookCallback;

        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule!;
        _hookHandle = NativeMethods.SetWindowsHookEx(
            NativeMethods.WH_KEYBOARD_LL,
            _hookProc,
            NativeMethods.GetModuleHandle(module.ModuleName),
            0);
    }

    /// <summary>
    /// Remove the keyboard hook.
    /// </summary>
    public void Uninstall()
    {
        if (_hookHandle != IntPtr.Zero)
        {
            NativeMethods.UnhookWindowsHookEx(_hookHandle);
            _hookHandle = IntPtr.Zero;
        }
        _hookProc = null;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            int msg = wParam.ToInt32();
            if (msg == NativeMethods.WM_KEYDOWN || msg == NativeMethods.WM_SYSKEYDOWN)
            {
                int vkCode = Marshal.ReadInt32(lParam);
                OnKeyDown?.Invoke(vkCode);
            }

            // Suppress all keyboard events when requested
            if (SuppressAll)
                return (IntPtr)1;
        }

        return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            Uninstall();
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    ~LowLevelKeyboardHook()
    {
        Dispose();
    }
}
