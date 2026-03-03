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
- **Dual scheduling**: `ForegroundScheduler` (in-app timer, works without notification permission) + `NotificationScheduler` (local notifications for background reminders). Dedup logic prevents double-triggering.
- Pre-schedules 30 `UNNotificationRequest` at random intervals; tops up when app returns to foreground
- Blackout presented as `fullScreenCover` when foreground timer fires, user taps notification, or via manual "Breathe now" button
- Settings stored in `UserDefaults` (same as macOS)
- Single target for both iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)
- WatchConnectivity: `Connectivity/WatchConnectivityManager.swift` syncs settings bidirectionally with the companion Apple Watch

### watchOS

- **SwiftUI** app with `@main` entry point, part of the iOS Xcode project (`ios/Awareness/Awareness.xcodeproj`)
- **No third-party dependencies** — only Apple frameworks (SwiftUI, WatchKit, UserNotifications, WatchConnectivity, HealthKit, WidgetKit)
- Uses **local notifications** (same 30-notification architecture as iOS) with default system sound
- Blackout presented as `fullScreenCover`; `WKExtendedRuntimeSession` in alarm mode with `start(at:)` schedules end-of-blackout haptic via `notifyUser(hapticType:repeatHandler:)` — the only API that works when the wrist is down and display is off
- **3-signal audio/haptic system**: reminder haptic (2× `.failure`) on notification arrival, synthesized double chime (440Hz → 660Hz via `AVAudioEngine`) at blackout start, end haptic (2× `.directionUp`) at blackout end
- Settings stored in `UserDefaults`, synced bidirectionally with companion iPhone via `WCSession.updateApplicationContext()`
- Shared source files via target membership: `BlackoutVisualType`, `TimeWindow`, `SettingsManager`, `HealthKitManager`, `UpdateChecker`, `ProgressTracker`
- WidgetKit complication extension for watch face (accessoryCircular, accessoryRectangular, accessoryInline)

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
    └── screenshot-guide.md             # Screenshot preparation guide

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
| Menu bar icon | SF Symbol `"yinyang"` (macOS 14+) with Unicode `"☯"` fallback |
| Overlay windows | One borderless `NSWindow` per `NSScreen.screens`, level `.screenSaver`, `canJoinAllSpaces + fullScreenAuxiliary` |
| Input capture | `BlackoutWindow` subclass (`canBecomeKey/Main = true`) + `NSApp.activate(ignoringOtherApps:)` + `CGEvent.tapCreate` to suppress global keystrokes (ESC passes through when handcuffs off); local + global mouse monitors for click-to-dismiss |
| Breathing animation | Text mode: pulsating scale (0.95↔1.06) + opacity (0.25↔0.8) on 3s cycle; image mode: pulsating scale (0.95↔1.06) + opacity (0.6↔1.0) on 3s cycle; plain black: subtle breathing circle |
| Scheduling | `DispatchSourceTimer` with random delay; auto-reschedules on settings change via Combine |
| Camera detection | `AVCaptureDevice.isInUseByAnotherApplication` (no TCC prompt) |
| Mic detection | CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` on input devices |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` for initial values |
| File access (sandbox) | Security-scoped bookmarks for user-selected images/videos; raw path fallback outside sandbox |
| Startclick confirmation | Optional "Ready to breathe?" prompt before blackout; `BlackoutConfirmationView` in `BlackoutContentView.swift`; `BlackoutWindowController` shows confirmation phase, then transitions to actual blackout on accept; decline skips without affecting stats; `startclickConfirmation` setting (default: off) |
| Snooze | `snoozeUntil: Date?` in UserDefaults; scheduler checks before firing; auto-resumes on expiry |
| Auto-resume on wake | `SystemStateDetector.onSystemDidBecomeActive` clears snooze and restarts scheduler when returning from sleep/lock while snoozed |
| Fade animation | `NSAnimationContext` with 2s duration and easing curves |
| Launch at Login | `SMAppService.mainApp` (macOS 13+) |
| Update checker | `URLSession` queries GitHub releases API once on startup; skipped in sandbox (App Store handles updates) |
| Distribution | SPM dev build (`make bundle`), Mac App Store (Xcode + sandbox), Direct (`make release-direct` + notarization) |
| Mindful Moments | `ProgressTracker.shared` stores daily triggered/completed counts in `UserDefaults`; donut chart (labeled "Discipline") + 14-day bar chart in `ProgressView`; menu item "Mindful Moments..." |
| Localization | `Localizable.xcstrings` string catalog with EN/DE; `String(localized:)` API |

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
| Mindful Moments | `ProgressTracker.Shared` stores daily triggered/completed counts in `progress.json` (`%APPDATA%`); donut chart (labeled "Discipline") + 14-day bar chart in `ProgressWindow`; menu item "Mindful Moments..." |
| Localization | `.resx` resource files (`Strings.resx` EN, `Strings.de.resx` DE); `Strings.Designer.cs` auto-generated accessor |

### iOS/iPadOS

| Topic | Approach |
|---|---|
| App lifecycle | SwiftUI `@main` with `UIApplicationDelegateAdaptor` for notification handling |
| Home header | Title ("Awareness reminder") above logo (72×72), then "Mindfulness in Action" (`.headline`) and "In stillness rests the strength" (`.subheadline`, secondary) |
| Scheduling (notifications) | `UNUserNotificationCenter` with 30 pre-scheduled `UNCalendarNotificationTrigger` requests |
| Scheduling (foreground) | `ForegroundScheduler.shared` — `Timer.scheduledTimer` on main RunLoop; fires `.showBlackout` notification; dedup with notifications (60s lookahead / 30s lookback); starts/stops on scene phase changes |
| Blackout | `fullScreenCover` presenting `BlackoutView` with `.statusBarHidden()` and `.persistentSystemOverlays(.hidden)` |
| Breathing animation | Text mode: pulsating scale (0.95↔1.06) + opacity (0.25↔0.8) on 3s cycle; image mode: pulsating scale (0.95↔1.06) + opacity (0.6↔1.0) on 3s cycle; plain black: subtle breathing circle; keeps display active |
| Active touch | `willPresent` shows banner+sound; user must tap to start blackout |
| Foreground notification | `userNotificationCenter(_:willPresent:)` shows banner+sound; records trigger for progress; user must tap to start blackout |
| Background notification | User taps notification → `didReceive response:` → records trigger → posts `.showBlackout` notification → shows blackout |
| Coordinated scheduling | iOS is master scheduler; `rescheduleAll()` pushes fire dates to watch via `WatchConnectivityManager.shared.pushScheduleToWatch()`; watch does not push fire dates back |
| Progress sync | `ProgressTracker.shared.connectivityContext()` / `applyFromConnectivityContext()` with max() merge |
| Trigger tracking | Notifications counted as triggered on delivery (`willPresent`), tap (`didReceive`), and via delivered-check on foreground return (`countDeliveredNotifications`); `countedTriggerIDs` Set prevents double-counting |
| Sound | `AVAudioSession(.playback)` so gong plays even in silent mode; notification uses custom sound |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` (same as macOS) |
| Snooze | Removes all pending notifications; reschedules on resume |
| Dismiss | Tap gesture (disabled in handcuffs mode); auto-dismiss timer with randomized duration |
| Image picker | `PhotosPicker` from PhotosUI; saves to app Documents directory |
| Video picker | `.fileImporter` with movie content types |
| HealthKit | `HealthKitManager.shared` logs `HKCategorySample(.mindfulSession)` after each blackout; opt-in via settings toggle |
| HealthKit prompt | One-time alert on first launch encourages enabling Apple Health; controlled by `healthKitPromptShown` flag; both "Enable" and "Not Now" set the flag to prevent repeat prompts |
| Haptics | `UIImpactFeedbackGenerator(style: .heavy)` at blackout start, `UINotificationFeedbackGenerator(.success)` at end; opt-in via `vibrationEnabled` |
| End flash | White `Color.white` overlay flashes for ~1s at end of blackout before fade-out; `endFlashEnabled` (default: on) |
| Update checker | Same as macOS — `URLSession` queries GitHub releases API once on startup |
| WatchConnectivity | `WatchConnectivityManager.shared` syncs settings to/from companion Apple Watch via `WCSession.updateApplicationContext()` |
| Mindful Moments | `ProgressTracker.shared` stores daily triggered/completed counts in `UserDefaults`; donut chart (labeled "Discipline") + 14-day bar chart in `ProgressView` |
| Localization | `Localizable.xcstrings` string catalog with EN/DE; `String(localized:)` API |

### watchOS

| Topic | Approach |
|---|---|
| App lifecycle | SwiftUI `@main` with `WKApplicationDelegateAdaptor` for notification handling |
| Scheduling | `UNUserNotificationCenter` with 30 pre-scheduled notifications (same as iOS), default system sound |
| Blackout | `fullScreenCover` presenting `BlackoutView`; `WKExtendedRuntimeSession` in **alarm mode** with `start(at:)` schedules end-of-blackout haptic at exact end time — `notifyUser(hapticType:repeatHandler:)` delivers haptic even when wrist is down and display is off (the only API that can); main-thread `Timer.scheduledTimer` with Date check catches up visually on wrist-raise; local notification as backup end signal |
| Breathing animation | Text mode: pulsating scale (0.94↔1.08) + opacity (0.25↔0.8) on 3s cycle; plain black: subtle breathing circle; wrapped in `TimelineView(.animation)` to signal continuous rendering and extend display-on time |
| Active touch | `willPresent` shows banner+sound; user must tap to start blackout |
| Foreground notification | `userNotificationCenter(_:willPresent:)` shows banner+sound; records trigger for progress; plays reminder haptic; user must tap to start blackout |
| Background notification | User taps notification → `didReceive response:` → records trigger → plays reminder haptic → posts `.showBlackout` notification → shows blackout |
| Coordinated scheduling | iOS is master scheduler; `applyCoordinatedSchedule()` uses iOS fire dates; falls back to random only when iOS dates unavailable or all in the past |
| Progress sync | Same ProgressTracker sync methods via target membership |
| Trigger tracking | Same architecture as iOS — `recordNotificationTriggered` + `countDeliveredNotifications` + dedup Set |
| Namaste confirmation | Namaste 🙏 shown for 1.5s after blackout fade-out; when alarm session fired (`hasFired` flag), BlackoutView skips namaste and ContentView shows it instead (system alarm UI covers the app during alarm dismiss) |
| Reminder haptic | `HapticPlayer.playReminder()` — 2× `.failure` pulses on notification arrival; opt-in via `reminderHapticEnabled` |
| Start chime | `ChimePlayer.shared.playStartChime()` — synthesized 440Hz → 660Hz via `AVAudioEngine` + `AVAudioSourceNode`; `.ambient` audio session respects silent mode; always plays (no toggle) |
| End haptic | `HapticPlayer.playEnd()` — 2× `.directionUp` pulses; opt-in via `hapticEndEnabled` |
| Settings storage | `UserDefaults.standard` with `register(defaults:)` (same as iOS/macOS) |
| Settings sync | `WCSession.updateApplicationContext()` — bidirectional, last-write-wins, `isApplyingRemoteContext` guard prevents sync loops |
| Snooze | Removes all pending notifications; syncs snooze state to companion iPhone |
| Dismiss | Tap gesture (disabled in handcuffs mode); auto-dismiss timer with randomized duration |
| HealthKit | Shared `HealthKitManager.shared` logs mindful sessions (same code as iOS via target membership) |
| Visual modes | Plain black or custom text only (no image/video on watch) |
| Complication | WidgetKit extension: `accessoryCircular` (☯ with status tint), `accessoryRectangular` ("Awareness" + next time), `accessoryInline` |
| Update checker | Same as iOS — `URLSession` queries GitHub releases API once on startup |
| Mindful Moments | Shared `ProgressTracker.shared` via target membership (same code as iOS); compact donut (labeled "Discipline") + 7-day chart in `ProgressView` |

## Configurable Settings

- **Active time window** — hours during which interruptions occur (default: 06:00–22:00)
- **Blackout duration range** — min and max duration for each blackout; random duration picked within range (default: 20–40 seconds)
- **Blackout visual** — plain black, custom text, image, or looping video (default: text "Breathe.")
- **Random interval range** — min and max delay between interruptions (default: 15–30 minutes)
- **Start gong** — play a higher-pitched sound when blackout begins (default: on)
- **End gong** — play a deeper sound when blackout ends (default: on)
- **Handcuffs mode** — if on, user cannot dismiss blackout early (default: off)
- **Startclick confirmation** (macOS only) — shows "Ready to breathe?" before each blackout; decline to skip without affecting statistics (default: off)
- **Snooze** — pause for 10/20/30/60/120 minutes or indefinitely
- **Apple Health** (iOS/watchOS) — log each blackout as Mindful Minutes in Apple Health (default: off)
- **Vibration** (iOS only) — haptic feedback at start (heavy impact) and end (success notification) of blackout (default: off)
- **End flash** (iOS/watchOS) — 1-second white screen blink at end of blackout, visible through closed eyelids (default: on)
- **Reminder haptic** (watchOS only) — Taptic Engine nudge when a notification arrives (default: on)
- **Start chime** (watchOS only) — synthesized double chime (440Hz → 660Hz) when blackout begins; always plays, respects system mute (no toggle)
- **End haptic** (watchOS only) — Taptic Engine feedback when blackout ends (default: on)
- **Mindful Moments** — view today's discipline donut, lifetime stats, and 14-day (macOS/iOS) or 7-day (watchOS) bar chart history; accessible from menu bar (macOS), navigation (iOS/watchOS), or tray menu (Windows)

## Notes for Development

### macOS

- The app icon is `SupportFiles/AppIcon.icns` (yin-yang design), referenced via `CFBundleIconFile` in Info.plist
- Resources (gong sounds, default image) are copied by the Makefile into `Contents/Resources/` and accessed via `Bundle.main` — not SPM's `Bundle.module`, which resolves to the .app root and breaks codesigning
- The global event tap for keystroke suppression requires Accessibility permission — degrades gracefully if not granted. `NSApp.activate(ignoringOtherApps: true)` ensures the overlay captures focus even without the tap. Global mouse monitor provides fallback click-to-dismiss when another app steals focus.
- Settings migration: old `gongEnabled` key is auto-migrated to `startGongEnabled` + `endGongEnabled`; old `blackoutDuration` key is auto-migrated to `minBlackoutDuration` + `maxBlackoutDuration`
- About dialog version is read dynamically from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` — see "Version Bumping" section below
- Update checker: `UpdateChecker.shared` fetches `api.github.com/repos/joergs-git/awareness/releases/latest`, strips `v` prefix from `tag_name`, compares against `CFBundleShortVersionString`. Menu item appears between "About" and "Quit" when an update is available. Skipped automatically in the sandbox (App Store handles updates).
- **Mac App Store distribution**: `Awareness.xcodeproj` at repo root references all sources in `Sources/Awareness/`. Uses `SupportFiles/Awareness.entitlements` (App Sandbox with network client + user-selected file access). Security-scoped bookmarks in `SettingsManager` preserve file access across launches. `DistributedNotificationCenter` won't deliver screen lock/screensaver notifications in the sandbox — sleep/wake via `NSWorkspace` still works.
- **Direct distribution**: `make bundle-signed` signs with Developer ID + hardened runtime using `SupportFiles/Awareness-Direct.entitlements`. `make release-direct` additionally creates a ZIP, submits for notarization, and staples the ticket. Requires one-time `xcrun notarytool store-credentials` setup.
- Xcode project uses A2/B2/C2/D2/E2/F2 hex IDs in `project.pbxproj` (iOS project uses A1/B1 series — no collision)
- **Mindful Moments (progress tracking)**: `ProgressTracker.shared` persists daily stats (triggered/completed counts, keyed by `yyyy-MM-dd`) in `UserDefaults`. `ProgressView` renders a donut chart (labeled "Discipline"), today/lifetime stats, and a 14-day bar chart. Opened from the menu bar ("Mindful Moments...") via `ProgressWindowController`.
- **Localization**: `Localizable.xcstrings` (string catalog) in `Resources/` with EN (development language) and DE translations. Uses `String(localized:)` throughout UI code.
- **Startclick confirmation**: `startclickConfirmation` setting (Bool, default false). `BlackoutWindowController` enters a confirmation phase before the actual blackout — `BlackoutConfirmationView` shows "Ready to breathe?" with Yes/No buttons. Accepting transitions to the normal blackout; declining dismisses without counting as completed or triggered. Confirmation windows use the same multi-screen overlay approach as regular blackouts.
- **Auto-resume on wake**: `SystemStateDetector.onSystemDidBecomeActive` callback in `AppDelegate` checks if snoozed or stopped — if so, clears snooze, restarts scheduler, and rebuilds menu. Otherwise just reschedules with a fresh random delay.

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
- **Mindful Moments (progress tracking)**: `ProgressTracker.Shared` persists daily stats in `progress.json` (same `%APPDATA%\Awareness\` directory as settings). `ProgressWindow` renders a donut chart (labeled "Discipline"), today/lifetime stats, and a 14-day bar chart. Opened from the tray context menu ("Mindful Moments...").
- **Localization**: `Strings.resx` (EN) and `Strings.de.resx` (DE) in `Resources/`. `Strings.Designer.cs` is auto-generated. All UI strings referenced via `Strings.KeyName`. Language follows system locale.

### iOS/iPadOS

- Reuses model files (`BlackoutVisualType`, `TimeWindow`), `UpdateChecker`, and `SettingsManager` from macOS with minimal changes
- `GongPlayer` adds `AVAudioSession.sharedInstance().setCategory(.playback)` so gong plays in silent mode
- The notification sound file must be in the app bundle as `.aiff` — iOS supports AIFF for custom notification sounds
- `NotificationScheduler` pre-schedules 30 notifications and tops up when the app returns to foreground (iOS limits pending notifications to 64)
- `adjustToActiveWindow()` shifts fire dates that fall outside the active time window to the start of the next active period
- About screen version is read dynamically from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` — see "Version Bumping" section below
- Update checker works identically to macOS
- **HealthKit integration**: `HealthKitManager.shared` logs each blackout as an `HKCategorySample(.mindfulSession)` that appears in Apple Health under "Mindful Minutes". Opt-in via `healthKitEnabled` toggle in Settings. Write-only access requested (`toShare: [mindfulType], read: []`). Silently skips if not authorized.
- Privacy descriptions in `project.pbxproj`: `NSPhotoLibraryUsageDescription` (PhotosPicker), `NSHealthUpdateUsageDescription` and `NSHealthShareUsageDescription` (HealthKit)
- HealthKit entitlement in `Awareness/Awareness.entitlements` (`com.apple.developer.healthkit`)
- **HealthKit encouragement**: On first launch, an alert prompts users to enable Apple Health logging. Controlled by `healthKitPromptShown` (Bool, default false). The `.task` guard checks `!settings.healthKitPromptShown` so the prompt is shown only once; both "Enable" and "Not Now" set `healthKitPromptShown = true` to dismiss permanently.
- **Haptic vibration**: `vibrationEnabled` setting (Bool, default false). Heavy impact at blackout start, success notification at end. No extra imports needed — UIKit haptics available via SwiftUI bridging. Does not work on simulator.
- **End flash**: `endFlashEnabled` setting (Bool, default true). White overlay layer with 0.15s ease-in, 1s hold, 0.15s ease-out. Main fade-out delayed by 1.3s when flash is active.
- **WatchConnectivity**: `Connectivity/WatchConnectivityManager.swift` on the iOS side syncs settings bidirectionally with the companion Apple Watch. Uses `objectWillChange` (not Combine merge chains) to observe settings changes — complex merge chains cause Swift type-checker timeouts. `isApplyingRemoteContext` guard prevents infinite sync loops. Required `sessionDidBecomeInactive` / `sessionDidDeactivate` stubs are iOS-only.
- **Coordinated scheduling**: iOS is the master scheduler. `NotificationScheduler.scheduledFireDates` stores fire dates from most recent `rescheduleAll()`. `WatchConnectivityManager.pushScheduleToWatch(_:)` sends fire dates as Unix timestamps in applicationContext. The watch does NOT send fire dates back to avoid sync loops. Both sides use `lastRemoteContextDate` timestamps (2s cooldown) to prevent debounced observers from echoing remote context changes.
- **Progress sync**: `ProgressTracker.connectivityContext()` and `applyFromConnectivityContext()` handle cross-device stats merge using max() strategy.
- **Mindful Moments (progress tracking)**: `ProgressTracker.shared` persists daily stats in `UserDefaults`. `ProgressView` renders a donut chart (labeled "Discipline"), today/lifetime stats, and a 14-day bar chart. Accessible from the main ContentView navigation ("Mindful Moments"). `ProgressTracker.swift` is shared with watchOS via target membership. Triggered count is recorded on notification delivery (`willPresent`, `didReceive`, and delivered-check on foreground return), not in BlackoutView — so ignored notifications are counted accurately. `countedTriggerIDs` Set in `NotificationScheduler` prevents double-counting.
- **Localization**: `Localizable.xcstrings` (string catalog) at `Awareness/Localizable.xcstrings` with EN and DE translations. Uses `String(localized:)` throughout UI code.
- **Chinese sunrise color scheme (v3.0)**: iOS ContentView uses warm cream-to-sand vertical `LinearGradient` with `.scrollContentBackground(.hidden)`. Donut charts use earthy `(0.72, 0.50, 0.38)`. Breathe now button uses `.title3` + `.controlSize(.large)` with warm amber-terracotta tint. `AquarelleBackground` uses amber/peach/dusty rose/warm gold blobs. Inspiration micro-task text shown below card banner in separate section (not inside card).
- **Foreground scheduler (v2.16)**: `ForegroundScheduler.shared` uses `Timer.scheduledTimer` on the main RunLoop to trigger blackouts while the app is in the foreground. Starts on `.active` scene phase, stops on `.background`/`.inactive`. Posts `.showBlackout` (same as notifications). Dedup: skips if `NotificationScheduler.nextNotificationDate` is within 60s; `willPresent` suppresses banner if `ForegroundScheduler.lastTriggerDate` is within 30s. Ensures the app functions without notification permission (Apple Guideline 4.5.4).
- **Micro-task auto-assign (v3.02)**: `currentMicroTask()` now auto-assigns from today's card pool if no task exists for today. No longer requires the first blackout to trigger assignment. The `microTaskShownToday` gate was removed from ContentView.
- **Home screen widget (v3.02)**: `AwarenessWidget` extension (target E50099) with systemSmall and systemMedium families. `WidgetDataBridge` writes a `WidgetSnapshot` to App Group shared `UserDefaults(suiteName: "group.com.joergsflow.awareness.ios")`. Widget reads independently via `WidgetSnapshotData`. Deep link: `widgetURL("awareness://breathe")` opens app and triggers blackout via `.onOpenURL`. `pbxproj` uses A5/B5/C5/D5/E5/F5 hex IDs. Bundle ID: `com.joergsflow.awareness.ios.widget`.

### watchOS

- Part of the iOS Xcode project (`ios/Awareness/Awareness.xcodeproj`), not a separate project
- Two targets: `AwarenessWatch` (watchOS app, E30099) and `AwarenessWatchComplication` (WidgetKit extension, E40099)
- `project.pbxproj` uses A3/B3/C3/D3/E3/F3/G3 hex IDs for watch target, A4/B4/C4/D4/E4/F4 for widget extension (iOS uses A1/B1, macOS uses A2/B2 — no collision)
- Shared files via target membership: `BlackoutVisualType.swift`, `TimeWindow.swift`, `SettingsManager.swift`, `HealthKitManager.swift`, `UpdateChecker.swift`, `ProgressTracker.swift`
- `SettingsManager.swift` uses `#if os(watchOS)` / `#if !os(watchOS)` guards for platform-specific settings (haptics on watch, gong/vibration/image/video on iOS; `endFlashEnabled` exists in both blocks)
- Watch-specific settings: `reminderHapticEnabled` (default: true), `hapticEndEnabled` (default: true)
- Settings migration: old `hapticStartEnabled` key auto-migrates to `reminderHapticEnabled` on first launch
- `ChimePlayer.shared` uses `AVAudioEngine` + `AVAudioSourceNode` for real-time synthesis; `.ambient` audio session respects watchOS silent mode; `stop()` called in `onDisappear` to clean up
- **End-of-blackout signal (alarm session)**: `AlarmSessionManager.shared` uses `WKExtendedRuntimeSession` in **alarm mode** (`WKBackgroundModes: alarm` in build settings). When a blackout starts, `scheduleEndAlarm(at:)` calls `start(at:)` to schedule the session for the exact end time. At the scheduled time, watchOS launches/resumes the app and calls `notifyUser(hapticType: .notification, repeatHandler:)` — this is the ONLY API that delivers haptic when the wrist is down and display is off. The haptic repeats every 10 seconds until the user taps "Stop" in the system alarm UI. A local notification (`UNTimeIntervalNotificationTrigger`) acts as a backup end signal. Main-thread `Timer.scheduledTimer` with Date check catches up visually on wrist-raise. `TimelineView(.animation(minimumInterval: 1.0))` extends display-on time before dimming.
- **Namaste after alarm dismiss**: `AlarmSessionManager.hasFired` flag is set `true` when the alarm fires. `BlackoutView.dismissBlackout()` checks this flag — if true, skips the in-view namaste (invisible behind system alarm UI) and sets `isPresented = false` immediately. `ContentView.onChange(of: showingBlackout)` detects the dismiss + `hasFired` and shows a 2s namaste overlay on top of ContentView instead. `resetHasFired()` clears the flag after use.
- Notifications use default system sound (no custom .aiff) and no image attachment (no UIKit on watchOS)
- WatchConnectivity sync: `objectWillChange` + 500ms debounce → `updateApplicationContext()`. `isApplyingRemoteContext` flag + `lastRemoteContextDate` (2s cooldown) prevent echo loops and debounce-timing bypasses.
- Complication widget extension shares `SettingsManager`, `BlackoutVisualType`, `TimeWindow`, `NotificationScheduler`, `HealthKitManager`, and `ProgressTracker` via target membership
- **Complication sync**: `WidgetCenter.shared.reloadAllTimelines()` called after WatchConnectivity sync, on ContentView `.task`, and after blackout dismiss — keeps practice card complication in sync with app (without this, complication refreshes only every ~30 min)
- Bundle IDs: `com.joergsflow.awareness.ios.watch` (watch app), `com.joergsflow.awareness.ios.watch.widget` (widget extension)
- `WKCompanionAppBundleIdentifier`: `com.joergsflow.awareness.ios`
- Entitlements: `AwarenessWatch/AwarenessWatch.entitlements` with `com.apple.developer.healthkit`
- iOS target has "Embed Watch Content" build phase that embeds `AwarenessWatch.app`; watch target has "Embed App Extensions" phase for the complication
- **Coordinated scheduling**: iOS is the master scheduler. `NotificationScheduler.applyCoordinatedSchedule(_:)` uses synced dates from iOS; falls back to `rescheduleAll()` only when no future dates available. Watch does NOT push fire dates back. `lastCoordinatedScheduleDate` prevents debounced settings observer from overwriting coordinated schedule.
- **Progress sync**: `ProgressTracker` sync is shared via target membership — same code as iOS
- **Mindful Moments (progress tracking)**: Shared `ProgressTracker.shared` (same code as iOS via target membership). `ProgressView.swift` is watch-specific with a compact layout: donut chart (labeled "Discipline"), today stats, and 7-day bar chart. Complication widget extension also has `ProgressTracker` via target membership.

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
