# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Awareness** is a cross-platform mindfulness/breathing timer (macOS + Windows + iOS/iPadOS) that randomly blacks out the screen for a few seconds, forcing the user to pause, breathe, and reset. A vipassana timer for computer work.

Repository: https://github.com/joergs-git/awareness
License: MIT

## Build & Run

### macOS

```bash
# Development (SPM + ad-hoc signing)
make run          # build + bundle + launch
make bundle       # build + bundle only (output: build/Awareness.app)
make clean        # remove build artifacts
swift build       # compile only (no .app bundle)

# Mac App Store (Xcode project + App Sandbox)
# Open Awareness.xcodeproj in Xcode, select "My Mac", build/archive

# Direct distribution (Developer ID + notarization)
make bundle-signed DEVELOPER_ID="Developer ID Application: Name (TEAMID)"
make release-direct   # bundle-signed + notarize + staple
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

### iOS/iPadOS

```bash
cd ios/Awareness
xcodebuild -project Awareness.xcodeproj -scheme Awareness \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or open `ios/Awareness/Awareness.xcodeproj` in Xcode and build for a simulator or device.

Requires iOS 16+, Xcode 15+.

## Architecture

### macOS

- **Swift Package Manager** project (`Package.swift`, swift-tools-version 5.9)
- **Xcode project** (`Awareness.xcodeproj` at repo root) for Mac App Store distribution with App Sandbox
- **AppKit** for menu bar + overlay windows, **SwiftUI** (hosted via `NSHostingView`) for settings UI and blackout content
- **No third-party dependencies** — only Apple frameworks (AppKit, SwiftUI, AVFoundation, CoreAudio, ServiceManagement)
- `Makefile` assembles the `.app` bundle (copies binary + Info.plist + AppIcon.icns + resources, ad-hoc codesign)
- `SupportFiles/Info.plist` — `LSUIElement=true` (menu bar only, hidden from Dock)
- Three distribution channels: SPM dev build (`make bundle`), Mac App Store (Xcode + sandbox), Direct (`make release-direct` + notarization)

### Windows

- **C# .NET 8** WPF project (`windows/Awareness/Awareness.csproj`)
- **WPF** for overlay windows + settings UI, **WinForms** for `Screen` enumeration
- **NuGet dependencies**: NAudio (audio playback + WASAPI mic detection), Hardcodet.NotifyIcon.Wpf (system tray icon)
- Tray-only app: `ShutdownMode="OnExplicitShutdown"`, single instance via named `Mutex`
- Settings persisted as JSON in `%APPDATA%\Awareness\settings.json`

### iOS/iPadOS

- **SwiftUI** app with `@main` entry point (no UIKit storyboards)
- **No third-party dependencies** — only Apple frameworks (SwiftUI, AVFoundation, UserNotifications, PhotosUI, HealthKit)
- Uses **local notifications** instead of background timers (iOS does not allow persistent background execution)
- Pre-schedules 30 `UNNotificationRequest` at random intervals; tops up when app returns to foreground
- Blackout presented as `fullScreenCover` when user taps notification or app is in foreground
- Settings stored in `UserDefaults` (same as macOS)
- Single target for both iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)

## Project Structure

### macOS (`Sources/Awareness/`)

```
Awareness.xcodeproj/                    # Xcode project for Mac App Store distribution
SupportFiles/
├── Info.plist                          # Bundle metadata (LSUIElement, category, copyright)
├── AppIcon.icns                        # Yin-yang app icon
├── Awareness.entitlements              # App Sandbox entitlements (Mac App Store)
└── Awareness-Direct.entitlements       # Hardened Runtime entitlements (direct distribution)

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
│   ├── MediaUsageDetector.swift        # AVCaptureDevice + CoreAudio queries
│   └── SystemStateDetector.swift       # Sleep/wake, display, lock, screensaver detection
├── Settings/
│   ├── SettingsManager.swift           # UserDefaults wrapper, security-scoped bookmarks
│   ├── SettingsWindowController.swift  # NSWindow hosting SwiftUI settings
│   └── SettingsView.swift              # SwiftUI Form, range slider, file pickers
├── Audio/
│   └── GongPlayer.swift               # AVAudioPlayer for start/end gong sounds
├── UpdateChecker.swift                 # GitHub release update checker (singleton)
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
├── UpdateChecker.cs                    # GitHub release update checker (singleton)
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

### iOS/iPadOS (`ios/Awareness/Awareness/`)

```
ios/Awareness/
├── Awareness.xcodeproj                 # Xcode project (iOS 16+, iPhone + iPad)
└── Awareness/
    ├── AwarenessApp.swift              # @main entry point, notification delegate
    ├── ContentView.swift               # Home screen (status, snooze, test, settings)
    ├── UpdateChecker.swift             # GitHub release update checker (singleton)
    ├── Awareness.entitlements          # HealthKit entitlement
    ├── Models/
    │   ├── BlackoutVisualType.swift    # Enum: plainBlack/text/image/video
    │   └── TimeWindow.swift           # Active hours model
    ├── Settings/
    │   ├── SettingsManager.swift       # UserDefaults wrapper, @ObservableObject
    │   └── SettingsView.swift          # iOS Form with NavigationStack, PhotosPicker
    ├── Audio/
    │   └── GongPlayer.swift           # AVAudioPlayer + AVAudioSession for silent mode
    ├── Blackout/
    │   └── BlackoutView.swift         # Full-screen blackout (UIImage, tap dismiss, video loop)
    ├── Notifications/
    │   └── NotificationScheduler.swift # UNUserNotificationCenter scheduling
    ├── Health/
    │   └── HealthKitManager.swift     # Mindful session logging to Apple Health
    ├── Assets.xcassets/                # App icon (1024x1024), accent color
    └── Resources/
        ├── awareness-gong.aiff         # Start gong (notification sound + in-app)
        ├── awareness-gong-end.aiff     # End gong (in-app only)
        └── default-blackout.png        # Default image for image mode
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
| File access (sandbox) | Security-scoped bookmarks for user-selected images/videos; raw path fallback outside sandbox |
| Snooze | `snoozeUntil: Date?` in UserDefaults; scheduler checks before firing; auto-resumes on expiry |
| Fade animation | `NSAnimationContext` with 2s duration and easing curves |
| Launch at Login | `SMAppService.mainApp` (macOS 13+) |
| Update checker | `URLSession` queries GitHub releases API once on startup; skipped in sandbox (App Store handles updates) |
| Distribution | SPM dev build (`make bundle`), Mac App Store (Xcode + sandbox), Direct (`make release-direct` + notarization) |

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
| Update checker | `HttpClient` queries GitHub releases API once on startup; shows menu item if newer version exists |

### iOS/iPadOS

| Topic | Approach |
|---|---|
| App lifecycle | SwiftUI `@main` with `UIApplicationDelegateAdaptor` for notification handling |
| Scheduling | `UNUserNotificationCenter` with 30 pre-scheduled `UNCalendarNotificationTrigger` requests |
| Blackout | `fullScreenCover` presenting `BlackoutView` with `.statusBarHidden()` and `.persistentSystemOverlays(.hidden)` |
| Foreground notification | `userNotificationCenter(_:willPresent:)` skips banner and shows blackout directly |
| Background notification | User taps notification → `didReceive response:` → posts `.showBlackout` notification → shows blackout |
| Sound | `AVAudioSession(.playback)` so gong plays even in silent mode; notification uses custom sound |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` (same as macOS) |
| Snooze | Removes all pending notifications; reschedules on resume |
| Dismiss | Tap gesture (disabled in handcuffs mode); auto-dismiss timer with randomized duration |
| Image picker | `PhotosPicker` from PhotosUI; saves to app Documents directory |
| Video picker | `.fileImporter` with movie content types |
| HealthKit | `HealthKitManager.shared` logs `HKCategorySample(.mindfulSession)` after each blackout; opt-in via settings toggle |
| Update checker | Same as macOS — `URLSession` queries GitHub releases API once on startup |

## Configurable Settings

- **Active time window** — hours during which interruptions occur (default: 06:00–20:00)
- **Blackout duration range** — min and max duration for each blackout; random duration picked within range (default: 20–20 seconds, i.e. fixed)
- **Blackout visual** — plain black, custom text, image, or looping video (default: text "Breathe.")
- **Random interval range** — min and max delay between interruptions (default: 15–30 minutes)
- **Start gong** — play a higher-pitched sound when blackout begins (default: on)
- **End gong** — play a deeper sound when blackout ends (default: on)
- **Handcuffs mode** — if on, user cannot dismiss blackout early (default: off)
- **Snooze** — pause for 10/20/30/60/120 minutes or indefinitely
- **Apple Health** (iOS only) — log each blackout as Mindful Minutes in Apple Health (default: off)

## Notes for Development

### macOS

- The app icon is `SupportFiles/AppIcon.icns` (yin-yang design), referenced via `CFBundleIconFile` in Info.plist
- Resources (gong sounds, default image) are copied by the Makefile into `Contents/Resources/` and accessed via `Bundle.main` — not SPM's `Bundle.module`, which resolves to the .app root and breaks codesigning
- The global event tap for keystroke suppression requires Accessibility permission — degrades gracefully if not granted
- Settings migration: old `gongEnabled` key is auto-migrated to `startGongEnabled` + `endGongEnabled`; old `blackoutDuration` key is auto-migrated to `minBlackoutDuration` + `maxBlackoutDuration`
- About dialog version is read dynamically from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` — update `SupportFiles/Info.plist` only when bumping versions
- Update checker: `UpdateChecker.shared` fetches `api.github.com/repos/joergs-git/awareness/releases/latest`, strips `v` prefix from `tag_name`, compares against `CFBundleShortVersionString`. Menu item appears between "About" and "Quit" when an update is available. Skipped automatically in the sandbox (App Store handles updates).
- **Mac App Store distribution**: `Awareness.xcodeproj` at repo root references all sources in `Sources/Awareness/`. Uses `SupportFiles/Awareness.entitlements` (App Sandbox with network client + user-selected file access). Security-scoped bookmarks in `SettingsManager` preserve file access across launches. `DistributedNotificationCenter` won't deliver screen lock/screensaver notifications in the sandbox — sleep/wake via `NSWorkspace` still works.
- **Direct distribution**: `make bundle-signed` signs with Developer ID + hardened runtime using `SupportFiles/Awareness-Direct.entitlements`. `make release-direct` additionally creates a ZIP, submits for notarization, and staples the ticket. Requires one-time `xcrun notarytool store-credentials` setup.
- Xcode project uses A2/B2/C2/D2/E2/F2 hex IDs in `project.pbxproj` (iOS project uses A1/B1 series — no collision)

### Windows

- Audio resources are `.wav` files converted from macOS `.aiff` via `afconvert -d LEI16 -f WAVE`
- The tray icon `.ico` was generated from the macOS iconset PNGs via `ffmpeg`
- Resources are embedded via `<Resource>` items in the `.csproj` and accessed with `pack://application:,,,/` URIs
- The `WH_KEYBOARD_LL` hook callback must return within ~300ms or Windows silently removes the hook
- Display power notifications require a window handle — `SystemStateDetector` creates a hidden message-only window (`HWND_MESSAGE`) for this
- `UseWindowsForms` is enabled in the `.csproj` for `System.Windows.Forms.Screen` multi-monitor enumeration
- Video looping uses `MediaElement` with `MediaEnded` handler resetting `Position` to zero
- About dialog version is read dynamically from the assembly version (`Version` in `.csproj`) — no hardcoded version strings
- Update checker: `UpdateChecker.Shared` uses `HttpClient` to query the GitHub releases API, compares `tag_name` against assembly version (`Version` in `.csproj`). Menu item appears between "About" and "Quit" when an update is available.
- Settings migration: if JSON has old `blackoutDuration` but no `minBlackoutDuration`/`maxBlackoutDuration`, the old value is mapped to both new fields

### iOS/iPadOS

- Reuses model files (`BlackoutVisualType`, `TimeWindow`), `UpdateChecker`, and `SettingsManager` from macOS with minimal changes
- `GongPlayer` adds `AVAudioSession.sharedInstance().setCategory(.playback)` so gong plays in silent mode
- The notification sound file must be in the app bundle as `.aiff` — iOS supports AIFF for custom notification sounds
- `NotificationScheduler` pre-schedules 30 notifications and tops up when the app returns to foreground (iOS limits pending notifications to 64)
- `adjustToActiveWindow()` shifts fire dates that fall outside the active time window to the start of the next active period
- About screen version is read dynamically from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` — update `MARKETING_VERSION` in the Xcode project when bumping versions
- Update checker works identically to macOS
- **HealthKit integration**: `HealthKitManager.shared` logs each blackout as an `HKCategorySample(.mindfulSession)` that appears in Apple Health under "Mindful Minutes". Opt-in via `healthKitEnabled` toggle in Settings. Write-only access requested (`toShare: [mindfulType], read: []`). Silently skips if not authorized.
- Privacy descriptions in `project.pbxproj`: `NSPhotoLibraryUsageDescription` (PhotosPicker), `NSHealthUpdateUsageDescription` and `NSHealthShareUsageDescription` (HealthKit)
- HealthKit entitlement in `Awareness/Awareness.entitlements` (`com.apple.developer.healthkit`)
