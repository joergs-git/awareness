# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Awareness reminder** is a cross-platform mindfulness/breathing timer (macOS + Windows + iOS/iPadOS + watchOS) that randomly blacks out the screen for a few seconds, forcing the user to pause, breathe, and reset. A vipassana timer for computer work.

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

### watchOS

The watchOS app is built as part of the iOS Xcode project:

```bash
cd ios/Awareness
xcodebuild -project Awareness.xcodeproj -scheme AwarenessWatch \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

Or open `ios/Awareness/Awareness.xcodeproj` in Xcode, select the `AwarenessWatch` scheme, and build for a watch simulator or device.

Requires watchOS 10+, Xcode 15+.

## Architecture

### macOS
- **SPM** project (`Package.swift`) + **Xcode project** (`Awareness.xcodeproj`) for Mac App Store
- **AppKit** menu bar + overlay windows, **SwiftUI** settings/blackout content (via `NSHostingView`)
- No third-party deps. Three distribution channels: SPM dev, Mac App Store (sandbox), Direct (notarized)
- `SupportFiles/Info.plist` — `LSUIElement=true` (menu bar only)

### Windows
- **C# .NET 8** WPF project. NuGet: NAudio (audio + mic), Hardcodet (tray icon)
- Tray-only: `ShutdownMode="OnExplicitShutdown"`, single instance via `Mutex`
- Settings: JSON in `%APPDATA%\Awareness\settings.json`

### iOS/iPadOS
- **SwiftUI** `@main`, no third-party deps. Dual scheduling: `ForegroundScheduler` (in-app) + `NotificationScheduler` (background)
- 30 pre-scheduled `UNNotificationRequest`; tops up on foreground return
- WatchConnectivity syncs settings bidirectionally; iOS is master scheduler for fire dates

### watchOS
- Part of iOS Xcode project. Shared files via target membership: `BlackoutVisualType`, `TimeWindow`, `SettingsManager`, `HealthKitManager`, `UpdateChecker`, `ProgressTracker`
- `WKExtendedRuntimeSession` alarm mode for end-of-blackout haptic (see `AlarmSessionManager.swift`)
- WidgetKit complication extension (circular/rectangular/inline)

## Project Structure

### macOS (`Sources/Awareness/`)

```
Awareness.xcodeproj/                    # Xcode project for Mac App Store distribution
SupportFiles/
├── Info.plist                          # Bundle metadata (LSUIElement, category, copyright)
├── AppIcon.icns                        # Yin-yang app icon
├── Awareness.entitlements              # App Sandbox entitlements (Mac App Store)
├── Awareness-Direct.entitlements       # Hardened Runtime entitlements (direct distribution)
└── AppStore/                           # App Store Connect metadata (EN/DE)
    ├── description-en.txt / -de.txt    # Full app description
    ├── whats-new-en.txt / -de.txt      # Release notes
    ├── keywords-en.txt / -de.txt       # Search keywords
    ├── subtitle-en.txt / -de.txt       # App subtitle
    ├── promotional-text-en.txt / -de.txt # Promotional text
    ├── screenshot-guide.md             # Screenshot preparation guide
    └── screenshots/capture.sh          # Simulator screenshot automation (setup/capture/teardown)

Sources/Awareness/
├── main.swift                          # NSApplication bootstrap
├── AppDelegate.swift                   # Central orchestrator
├── MenuBar/
│   └── StatusBarController.swift       # NSStatusItem, menu, snooze, about
├── Blackout/
│   ├── BlackoutScheduler.swift         # Random timer, active-window + media checks
│   ├── BlackoutWindowController.swift  # Full-screen overlay per monitor, fade, keystroke suppression, startclick confirmation
│   └── BlackoutContentView.swift       # SwiftUI view (black/text/image/video) + startclick confirmation view
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
├── Progress/
│   ├── ProgressTracker.swift           # Singleton tracking triggered/completed blackouts per day
│   ├── ProgressView.swift             # SwiftUI donut chart, today stats, 14-day bar chart
│   └── ProgressWindowController.swift # NSWindow hosting SwiftUI progress view
└── Resources/
    ├── Localizable.xcstrings           # String catalog (EN/DE localization)
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
├── Progress/
│   ├── ProgressTracker.cs              # Singleton tracking triggered/completed blackouts per day
│   └── ProgressWindow.xaml/.cs         # WPF progress window with donut chart, stats, bar chart
└── Resources/
    ├── Strings.resx                    # English resource strings (localization)
    ├── Strings.de.resx                 # German resource strings (localization)
    ├── Strings.Designer.cs             # Auto-generated string accessor class
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
    ├── ContentView.swift               # Home screen (header, status, snooze, test, settings)
    ├── UpdateChecker.swift             # GitHub release update checker (singleton)
    ├── Awareness.entitlements          # HealthKit + App Group entitlements
    ├── Info.plist                     # URL scheme registration (awareness://)
    ├── WidgetDataBridge.swift         # Writes snapshot to App Group shared UserDefaults for widget
    ├── Models/
    │   ├── BlackoutVisualType.swift    # Enum: plainBlack/text/image/video
    │   └── TimeWindow.swift           # Active hours model
    ├── Settings/
    │   ├── SettingsManager.swift       # UserDefaults wrapper, @ObservableObject
    │   └── SettingsView.swift          # iOS Form with NavigationStack, PhotosPicker
    ├── Audio/
    │   └── GongPlayer.swift           # AVAudioPlayer + AVAudioSession for silent mode
    ├── Blackout/
    │   ├── BlackoutView.swift         # Full-screen blackout (UIImage, tap dismiss, video loop)
    │   └── ForegroundScheduler.swift  # In-app timer for foreground blackouts (no notification permission needed)
    ├── Notifications/
    │   └── NotificationScheduler.swift # UNUserNotificationCenter scheduling
    ├── Health/
    │   └── HealthKitManager.swift     # Mindful session logging to Apple Health
    ├── Progress/
    │   ├── ProgressTracker.swift       # Singleton tracking triggered/completed blackouts per day
    │   └── ProgressView.swift         # SwiftUI donut chart, today stats, 14-day bar chart
    ├── Connectivity/
    │   └── WatchConnectivityManager.swift  # iOS-side WCSession delegate for watch sync
    ├── Localizable.xcstrings           # String catalog (EN/DE localization)
    ├── Assets.xcassets/                # App icon (1024x1024), accent color
    └── Resources/
        ├── awareness-gong.aiff         # Start gong (notification sound + in-app)
        ├── awareness-gong-end.aiff     # End gong (in-app only)
        └── default-blackout.png        # Default image for image mode
```

### watchOS (`ios/Awareness/AwarenessWatch/`)

```
ios/Awareness/AwarenessWatch/
├── AwarenessWatchApp.swift             # @main entry point, WKApplicationDelegateAdaptor, notification delegate
├── ContentView.swift                   # Status, next blackout, test, snooze, settings link
├── BlackoutView.swift                  # Full-screen blackout with alarm session end signal
├── AlarmSessionManager.swift           # WKExtendedRuntimeSession alarm mode for reliable end haptic
├── SettingsView.swift                  # Compact Form: hours, intervals, duration, haptics, health
├── HapticPlayer.swift                  # WKInterfaceDevice haptic wrapper (reminder .failure / end .directionUp)
├── ChimePlayer.swift                   # AVAudioEngine synthesized double chime (440Hz → 660Hz) for blackout start
├── NotificationScheduler.swift         # 30 pre-scheduled notifications, no image attachment
├── ProgressView.swift                  # Compact progress display (donut, today stats, 7-day chart)
├── WatchConnectivityManager.swift      # watchOS-side WCSession delegate for iPhone sync
├── AwarenessWatch.entitlements         # HealthKit entitlement
├── Assets.xcassets/                    # Watch app icon (1024x1024), accent color
└── Complications/
    └── ComplicationProvider.swift      # WidgetKit TimelineProvider + circular/rectangular/inline views
```

### iOS Home Screen Widget (`ios/Awareness/AwarenessWidget/`)

```
ios/Awareness/AwarenessWidget/
├── AwarenessWidgetBundle.swift       # @main WidgetBundle entry point
├── AwarenessWidgetProvider.swift     # TimelineProvider + systemSmall/Medium views + WidgetSnapshotData
├── AwarenessWidget.entitlements      # App Group entitlement
├── Info.plist                        # NSExtension = com.apple.widgetkit-extension
└── Assets.xcassets/                  # AccentColor + AppIcon (minimal)
```

## Key Technical Decisions

### macOS

| Topic | Approach |
|---|---|
| Menu bar icon | SF Symbol `"yinyang"` (macOS 14+), Unicode `"☯"` fallback |
| Overlay windows | See `BlackoutWindowController.swift` header comment |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` |
| File access (sandbox) | Security-scoped bookmarks for user-selected images/videos |
| Snooze | `snoozeUntil: Date?` in UserDefaults; auto-resumes on expiry and wake |
| Launch at Login | `SMAppService.mainApp` (macOS 13+) |
| Distribution | SPM dev (`make bundle`), Mac App Store (Xcode + sandbox), Direct (`make release-direct`) |
| Localization | `Localizable.xcstrings` string catalog (EN/DE); `String(localized:)` |

### Windows

| Topic | Approach |
|---|---|
| System tray | Hardcodet `TaskbarIcon` + WPF `ContextMenu` |
| Overlay windows | One `Window` per `Screen.AllScreens`, `Topmost`, `WindowStyle=None` |
| Keyboard hook | `WH_KEYBOARD_LL` — callback must return within ~300ms |
| Settings storage | JSON in `%APPDATA%\Awareness\settings.json` with `INotifyPropertyChanged` |
| Launch at Login | Registry `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` |
| Single instance | Named `Mutex("Awareness-SingleInstance")` |
| Audio | NAudio `WaveOutEvent`, self-disposing playback |
| Localization | `.resx` files (EN/DE); `Strings.Designer.cs` auto-generated |

### iOS/iPadOS

| Topic | Approach |
|---|---|
| Dual scheduling | `ForegroundScheduler` (in-app) + `NotificationScheduler` (background). See `ForegroundScheduler.swift` header |
| Coordinated scheduling | iOS is master; pushes fire dates to watch. Watch does NOT push back |
| Trigger tracking | Counted on delivery (`willPresent`), tap (`didReceive`), foreground return. `countedTriggerIDs` dedup Set |
| HealthKit | `HealthKitManager.shared` logs `HKCategorySample(.mindfulSession)`; opt-in; write-only |
| Sound | `AVAudioSession(.playback)` for silent mode; notification uses custom `.aiff` |
| WatchConnectivity | `objectWillChange` (not Combine merge chains — type-checker timeouts). `isApplyingRemoteContext` + 2s cooldown |
| Home screen widget | `WidgetDataBridge` writes to App Group shared UserDefaults; deep link `awareness://breathe` |
| Localization | `Localizable.xcstrings` string catalog (EN/DE); `String(localized:)` |

### watchOS

| Topic | Approach |
|---|---|
| End-of-blackout signal | `AlarmSessionManager` — see source file header for full details |
| Coordinated scheduling | `applyCoordinatedSchedule()` uses iOS fire dates; random fallback only |
| Settings sync | `WCSession.updateApplicationContext()` — bidirectional, `isApplyingRemoteContext` guard |
| Complication sync | `WidgetCenter.shared.reloadAllTimelines()` — called after sync, on `.task`, after blackout |
| Notifications | Default system sound (no custom .aiff); no image attachment (no UIKit) |
| Visual modes | Plain black or custom text only (no image/video) |

## Configurable Settings

- **Active time window** — hours during which interruptions occur (default: 06:00–22:00)
- **Blackout duration range** — min/max duration; random within range (default: 20–40s)
- **Blackout visual** — plain black, custom text, image, or looping video (default: rotating text phrases)
- **Random interval range** — min/max delay between interruptions (default: 15–30 min)
- **Start/End gong** — sounds at blackout start/end (default: on)
- **Handcuffs mode** — cannot dismiss early (default: off)
- **Startclick confirmation** (macOS only) — "Ready to breathe?" prompt (default: off)
- **Snooze** — pause for 10/20/30/60/120 min or indefinitely
- **Apple Health** (iOS/watchOS) — log as Mindful Minutes (default: off)
- **Vibration** (iOS, default: on), **Reminder/End haptic** (watchOS) — tactile feedback
- **End flash** (iOS/watchOS) — white blink at blackout end (default: on)
- **Start chime** (watchOS) — synthesized 440Hz→660Hz, respects mute (always on)

## Notes for Development

### macOS
- Resources accessed via `Bundle.main` (not `Bundle.module` — breaks codesigning)
- Settings migration: `gongEnabled` → `startGongEnabled` + `endGongEnabled`; `blackoutDuration` → min/max
- Mac App Store: `SupportFiles/Awareness.entitlements` (sandbox). `DistributedNotificationCenter` won't deliver in sandbox
- Direct: `SupportFiles/Awareness-Direct.entitlements`. Requires `xcrun notarytool store-credentials` setup
- Xcode project hex IDs: A2/B2/C2/D2/E2/F2 (iOS uses A1/B1 — no collision)

### Windows
- Audio: `.wav` converted from `.aiff` via `afconvert -d LEI16 -f WAVE`
- Icon: `.ico` generated from PNGs via `ffmpeg`
- `UseWindowsForms` in `.csproj` for `Screen` multi-monitor enumeration
- Display power notifications need hidden message-only window (`HWND_MESSAGE`)
- Settings migration: `blackoutDuration` → `minBlackoutDuration`/`maxBlackoutDuration`

### iOS/iPadOS
- Privacy descriptions in `project.pbxproj`: `NSPhotoLibraryUsageDescription`, `NSHealthUpdateUsageDescription`, `NSHealthShareUsageDescription`
- HealthKit entitlement in `Awareness/Awareness.entitlements`
- Notification sound must be bundled `.aiff` (iOS requirement)
- Widget: target E50099, pbxproj hex IDs A5/B5/C5/D5/E5/F5. App Group: `group.com.joergsflow.awareness.ios`

### watchOS
- Two targets: `AwarenessWatch` (E30099), `AwarenessWatchComplication` (E40099)
- pbxproj hex IDs: A3/B3/C3/D3/E3/F3/G3 (watch), A4/B4/C4/D4/E4/F4 (widget)
- `SettingsManager.swift` uses `#if os(watchOS)` guards for platform-specific settings
- Bundle IDs: `com.joergsflow.awareness.ios.watch`, `.watch.widget`
- `WKCompanionAppBundleIdentifier`: `com.joergsflow.awareness.ios`

## Changelog

`CHANGELOG.md` at the repo root contains the full cumulative version history from v1.0 to the current release. Update it when bumping the version. The App Store `whats-new-*.txt` files are overwritten each release (not cumulative).

## Version Bumping

When bumping the version, update **all four files** (no hardcoded version strings elsewhere — all read dynamically at runtime):

| File | Field | Format |
|---|---|---|
| `SupportFiles/Info.plist` | `CFBundleVersion` + `CFBundleShortVersionString` | `X.Y` |
| `Awareness.xcodeproj/project.pbxproj` | `MARKETING_VERSION` (2 targets: Debug + Release) | `X.Y` |
| `ios/Awareness/Awareness.xcodeproj/project.pbxproj` | `MARKETING_VERSION` (8 targets: iOS Debug/Release, watchOS Debug/Release, watchOS widget Debug/Release, iOS widget Debug/Release) | `X.Y` |
| `windows/Awareness/Awareness.csproj` | `<Version>` | `X.Y.0` |
