# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Awareness** is a cross-platform mindfulness/breathing timer (macOS + Windows) that randomly blacks out the screen for a few seconds, forcing the user to pause, breathe, and reset. A vipassana timer for computer work.

Repository: https://github.com/joergs-git/awareness
License: MIT

## Build & Run

### macOS

```bash
make run          # build + bundle + launch
make bundle       # build + bundle only (output: build/Awareness.app)
make clean        # remove build artifacts
swift build       # compile only (no .app bundle)
```

Requires macOS 13+, Xcode Command Line Tools, Swift 5.9+.

### Windows

```bash
cd windows
dotnet build                              # compile
dotnet run --project Awareness            # compile + run
dotnet publish Awareness -c Release -r win-x64   # self-contained exe
```

Requires Windows 10+, .NET 8 SDK.

## Architecture

### macOS

- **Swift Package Manager** project (`Package.swift`, swift-tools-version 5.9)
- **AppKit** for menu bar + overlay windows, **SwiftUI** (hosted via `NSHostingView`) for settings UI and blackout content
- **No third-party dependencies** — only Apple frameworks (AppKit, SwiftUI, AVFoundation, CoreAudio, ServiceManagement)
- `Makefile` assembles the `.app` bundle (copies binary + Info.plist + AppIcon.icns + resources, ad-hoc codesign)
- `SupportFiles/Info.plist` — `LSUIElement=true` (menu bar only, hidden from Dock)

### Windows

- **C# .NET 8** WPF project (`windows/Awareness/Awareness.csproj`)
- **WPF** for overlay windows + settings UI, **WinForms** for `Screen` enumeration
- **NuGet dependencies**: NAudio (audio playback + WASAPI mic detection), Hardcodet.NotifyIcon.Wpf (system tray icon)
- Tray-only app: `ShutdownMode="OnExplicitShutdown"`, single instance via named `Mutex`
- Settings persisted as JSON in `%APPDATA%\Awareness\settings.json`

## Project Structure

### macOS (`Sources/Awareness/`)

```
Sources/Awareness/
├── main.swift                          # NSApplication bootstrap
├── AppDelegate.swift                   # Central orchestrator
├── MenuBar/
│   └── StatusBarController.swift       # NSStatusItem, menu, snooze, about
├── Blackout/
│   ├── BlackoutScheduler.swift         # Random timer, active-window + media checks
│   ├── BlackoutWindowController.swift  # Full-screen overlay per monitor, fade, keystroke suppression
│   └── BlackoutContentView.swift       # SwiftUI view (black/text/image/video)
├── Detection/
│   └── MediaUsageDetector.swift        # AVCaptureDevice + CoreAudio queries
├── Settings/
│   ├── SettingsManager.swift           # UserDefaults wrapper, @ObservableObject
│   ├── SettingsWindowController.swift  # NSWindow hosting SwiftUI settings
│   └── SettingsView.swift              # SwiftUI Form, range slider, file pickers
├── Audio/
│   └── GongPlayer.swift               # AVAudioPlayer for start/end gong sounds
├── Models/
│   ├── BlackoutVisualType.swift        # Enum: plainBlack/text/image/video
│   └── TimeWindow.swift               # Active hours model
└── Resources/
    ├── awareness-gong.aiff             # Higher-pitched start gong
    ├── awareness-gong-end.aiff         # Deeper-pitched end gong
    └── default-blackout.png            # Default image for image mode
```

### Windows (`windows/Awareness/`)

```
windows/Awareness/
├── Awareness.csproj                    # .NET 8 WinExe project
├── App.xaml / App.xaml.cs              # Bootstrap, single instance, tray-only
├── Models/
│   ├── BlackoutVisualType.cs           # Enum with serialization helpers
│   └── TimeWindow.cs                   # Active hours model
├── Audio/
│   └── GongPlayer.cs                   # NAudio WaveOutEvent playback
├── Blackout/
│   ├── BlackoutScheduler.cs            # Random timer, checks, reactive settings
│   ├── BlackoutWindowController.cs     # Per-monitor overlay management
│   ├── BlackoutOverlayWindow.xaml/.cs  # Fullscreen WPF window with fade
│   └── BlackoutContentControl.xaml/.cs # Text/image/video content
├── Detection/
│   ├── MediaUsageDetector.cs           # Registry camera + WASAPI mic check
│   └── SystemStateDetector.cs          # Sleep/wake, lock, display, screensaver
├── MenuBar/
│   └── TrayIconController.cs           # Hardcodet TaskbarIcon + context menu
├── Settings/
│   ├── SettingsManager.cs              # JSON persistence, INotifyPropertyChanged
│   ├── SettingsWindow.xaml/.cs         # WPF settings form
│   └── RangeSlider.xaml/.cs            # Custom dual-thumb slider control
├── Interop/
│   ├── NativeMethods.cs                # P/Invoke declarations
│   └── LowLevelKeyboardHook.cs         # WH_KEYBOARD_LL keystroke suppression
└── Resources/
    ├── awareness-gong.wav              # Start gong (converted from .aiff)
    ├── awareness-gong-end.wav          # End gong (converted from .aiff)
    ├── default-blackout.png            # Default image for image mode
    └── tray-icon.ico                   # Yin-yang tray icon
```

## Key Technical Decisions

### macOS

| Topic | Approach |
|---|---|
| Menu bar icon | SF Symbol `"yinyang"` (macOS 14+) with Unicode `"☯"` fallback |
| Overlay windows | One borderless `NSWindow` per `NSScreen.screens`, level `.screenSaver`, `canJoinAllSpaces + fullScreenAuxiliary` |
| Keyboard capture | `BlackoutWindow` subclass (`canBecomeKey = true`) + `CGEvent.tapCreate` to suppress global keystrokes |
| Scheduling | `DispatchSourceTimer` with random delay; auto-reschedules on settings change via Combine |
| Camera detection | `AVCaptureDevice.isInUseByAnotherApplication` (no TCC prompt) |
| Mic detection | CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` on input devices |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` for initial values |
| Snooze | `snoozeUntil: Date?` in UserDefaults; scheduler checks before firing; auto-resumes on expiry |
| Fade animation | `NSAnimationContext` with 2s duration and easing curves |
| Launch at Login | `SMAppService.mainApp` (macOS 13+) |

### Windows

| Topic | Approach |
|---|---|
| System tray icon | Hardcodet `TaskbarIcon` + WPF `ContextMenu` |
| Overlay windows | One `Window` per `Screen.AllScreens`, `Topmost`, `WindowStyle=None`, `AllowsTransparency` |
| Keyboard capture | `SetWindowsHookEx(WH_KEYBOARD_LL)` — no special permissions needed |
| Scheduling | `DispatcherTimer` with random delay; reschedules on `PropertyChanged` with 500ms debounce |
| Camera detection | Registry `CapabilityAccessManager\ConsentStore\webcam` (`LastUsedTimeStop == 0`) |
| Mic detection | NAudio `MMDeviceEnumerator`, WASAPI session state checks |
| Settings storage | JSON file in `%APPDATA%\Awareness\settings.json` with `INotifyPropertyChanged` |
| Snooze | `SnoozeUntil: DateTime?` in JSON; scheduler checks before firing; auto-resumes on expiry |
| Fade animation | `DoubleAnimation` on `Opacity` with `CubicEase` (2s duration) |
| Launch at Login | Registry `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` |
| Sleep/wake | `SystemEvents.PowerModeChanged` (Suspend/Resume) |
| Screen lock | `SystemEvents.SessionSwitch` (SessionLock/Unlock) |
| Display off | `RegisterPowerSettingNotification(GUID_CONSOLE_DISPLAY_STATE)` via hidden message window |
| Screensaver | `SystemParametersInfo(SPI_GETSCREENSAVERRUNNING)` polled every 5s |
| DPI scaling | `Screen.Bounds / dpiScale` fallback for tray-only apps without a main window |
| Audio | NAudio `WaveOutEvent` with self-disposing playback (new instance per gong) |
| Single instance | Named `Mutex("Awareness-SingleInstance")` |

## Configurable Settings

- **Active time window** — hours during which interruptions occur (default: 06:00–20:00)
- **Blackout duration** — how long the screen stays blacked out (default: 20 seconds)
- **Blackout visual** — plain black, custom text, image, or looping video (default: text "Breathe.")
- **Random interval range** — min and max delay between interruptions (default: 15–30 minutes)
- **Start gong** — play a higher-pitched sound when blackout begins (default: on)
- **End gong** — play a deeper sound when blackout ends (default: on)
- **Handcuffs mode** — if on, user cannot dismiss blackout early (default: off)
- **Snooze** — pause for 10/20/30/60/120 minutes or indefinitely

## Notes for Development

### macOS

- The app icon is `SupportFiles/AppIcon.icns` (yin-yang design), referenced via `CFBundleIconFile` in Info.plist
- Resources (gong sounds, default image) are copied by the Makefile into `Contents/Resources/` and accessed via `Bundle.main` — not SPM's `Bundle.module`, which resolves to the .app root and breaks codesigning
- The global event tap for keystroke suppression requires Accessibility permission — degrades gracefully if not granted
- Settings migration: old `gongEnabled` key is auto-migrated to `startGongEnabled` + `endGongEnabled`

### Windows

- Audio resources are `.wav` files converted from macOS `.aiff` via `afconvert -d LEI16 -f WAVE`
- The tray icon `.ico` was generated from the macOS iconset PNGs via `ffmpeg`
- Resources are embedded via `<Resource>` items in the `.csproj` and accessed with `pack://application:,,,/` URIs
- The `WH_KEYBOARD_LL` hook callback must return within ~300ms or Windows silently removes the hook
- Display power notifications require a window handle — `SystemStateDetector` creates a hidden message-only window (`HWND_MESSAGE`) for this
- `UseWindowsForms` is enabled in the `.csproj` for `System.Windows.Forms.Screen` multi-monitor enumeration
- Video looping uses `MediaElement` with `MediaEnded` handler resetting `Position` to zero
