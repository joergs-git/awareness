# Atempause ☯

A mindfulness timer for macOS, Windows, iOS/iPadOS, and Apple Watch that randomly blacks out your screen for a few seconds, gently forcing you to pause, breathe, and return to the present moment.

## Why?

In the Vipassana meditation tradition, awareness (*sati*) is the foundation of all practice. The Buddha described it as the direct path to liberation: observing body, feelings, mind, and mental objects with clear comprehension, moment to moment, without clinging or aversion.

The challenge is that we spend hours each day staring at screens — answering emails, writing code, scrolling feeds — and gradually lose contact with ourselves. We forget to breathe deeply. We forget we even have a body. The mind narrows into a tunnel of tasks, and the day slips by on autopilot.

**Atempause** interrupts this pattern. A few times per hour, your screen gently fades to black. For 10, 20, or 30 seconds, there is nothing to do. You can close your eyes. Feel your breath. Notice your posture. Notice what your mind was just doing. Then the screen returns, and you continue — but now with a small gap of clarity inserted into your day.

This is not a break timer or a productivity tool. It is a practice aid. If you are walking the path of wisdom — whether through Vipassana, Zen, mindfulness-based practice, or simply a wish to be more present — these micro-interruptions become anchors of awareness threaded through your working day.

The Satipatthana Sutta teaches: *"A monk lives contemplating the body in the body, ardent, clearly comprehending, and mindful, having put away covetousness and grief for the world."* Awareness brings a tiny echo of that instruction into the digital workspace.

Have also a look into the wiki section of this project: (https://github.com/joergs-git/awareness/wiki/Home-%E2%80%90-Awareness-Reminder)

## Features

- **Menu bar / system tray app** — runs quietly with a ☯ icon, no Dock or Taskbar clutter
- **Random blackout intervals** — configurable min/max range (e.g. 15–30 minutes) so interruptions feel natural, not mechanical
- **Configurable duration range** — 3 to 120 seconds per blackout, with optional random variation between a min/max range
- **Smart detection** — automatically skips blackouts when your camera or microphone is in use (macOS/Windows) or during phone and video calls (iOS via CallKit — FaceTime, Zoom, Teams, WhatsApp). Skipped breaks are not counted in statistics.
- **Active time window** — only interrupts during configured hours (e.g. 06:00–20:00)
- **Visual modes** — plain black, custom text ("Breathe."), an image, or a looping video
- **Start and end gong** — an audible tone marks the beginning (higher pitch) and end (deeper pitch) of each blackout, so you know when to return even with eyes closed
- **Handcuffs mode** — when enabled, you cannot dismiss the blackout early. Commit to the practice.
- **Snooze** — pause the timer for 10 minutes up to 2 hours, or indefinitely until you resume
- **Fade transitions** — screen fades in/out over 2 seconds for a gentle experience
- **Keystroke suppression** — during blackout, keystrokes are blocked so you don't accidentally type into background apps
- **Multi-monitor support** — blacks out all connected displays simultaneously
- **Launch at Login** — start automatically with your Mac or PC
- **Persistent settings** — all preferences are saved and restored across app restarts
- **Default image** — a bundled dark visual is shown when image mode is selected but no custom image is configured
- **Apple Health integration** (iOS) — each mindful pause is logged as Mindful Minutes in Apple Health, so you can track your practice over time
- **Haptic vibration** (iOS) — optional vibration at the start and end of each blackout, useful when the phone is on silent and your eyes are closed
- **End flash** (iOS) — optional 1-second white screen blink at the end of a blackout, visible through closed eyelids to signal the session is ending
- **Apple Watch companion** — standalone watchOS app with haptic feedback, notification scheduling, and WidgetKit complications for your watch face
- **Cross-platform sync** — desktop breaks (macOS/Windows) sync to your iPhone via Supabase. Generate a sync key on iOS, enter it on your desktop app — your breaks count toward iPhone stats and Apple Health. Anonymous, no account needed
- **Settings sync** — bidirectional settings sync between iPhone and Apple Watch via WatchConnectivity
- **Active touch blackouts** (iOS/watchOS) — notifications require a tap; no auto-triggering when the app is in the foreground
- **Coordinated scheduling** — iPhone generates notification times and syncs them to Apple Watch, so both devices stay in harmony
- **Cross-device progress sync** — your practice stats merge between iPhone and Apple Watch via WatchConnectivity
- **Awareness check** — after each completed breathing moment, a quick question: "Were you there?" with three responses (Yes / Somewhat / No), tracked over time across all platforms
- **Practice cards & micro-tasks** — 7 daily mindfulness themes with 58 contemplative micro-tasks, shown after each awareness check (macOS/Windows/iOS/watchOS)
- **Watch face complications** — see your status and next blackout time directly on your watch face (circular, rectangular, and inline styles)
- **Progress tracking** — donut charts for discipline, 14-day bar charts for triggered/completed breaks and awareness responses
- **Localization** — English and German (EN/DE)
- **Update checker** — checks GitHub for newer releases on startup and shows an "Update Available" menu item linking to the download page

## Installation

### macOS

#### Download (easiest)

1. Download the latest `Awareness.app.zip` from the [Releases](https://github.com/joergs-git/awareness/releases) page
2. Unzip and move `Awareness.app` to your `/Applications` folder
3. Double-click to launch

The app is signed and notarized by Apple — it should open without any Gatekeeper warnings.

#### Build from source

Requirements: macOS 13+, Xcode Command Line Tools

```bash
git clone https://github.com/joergs-git/awareness.git
cd awareness
make run
```

This compiles the Swift source, assembles the `.app` bundle with ad-hoc code signing, and launches it.

To just build without launching:
```bash
make bundle
```

The app will be at `build/Awareness.app`.

### Windows

#### Download (easiest)

1. Download the latest `Awareness-Windows-x64.zip` from the [Releases](https://github.com/joergs-git/awareness/releases) page
2. Unzip and run `Awareness.exe`
3. The app appears as a ☯ icon in the system tray (bottom-right)

**Note:** Windows SmartScreen may show an "unknown publisher" warning until code signing is set up. Click "More info" → "Run anyway" to proceed.

#### Build from source

Requirements: Windows 10+, [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

```bash
git clone https://github.com/joergs-git/awareness.git
cd awareness/windows
dotnet build
dotnet run --project Awareness
```

To publish a self-contained executable:
```bash
dotnet publish Awareness -c Release -r win-x64
```

The output will be in `Awareness/bin/Release/net8.0-windows/win-x64/publish/`.

Windows builds are also produced automatically via GitHub Actions on each release tag.

### iOS/iPadOS

#### Build from source

Requirements: iOS 16+, Xcode 15+

```bash
git clone https://github.com/joergs-git/awareness.git
cd awareness/ios/Awareness
xcodebuild -project Awareness.xcodeproj -scheme Awareness \
    -destination 'generic/platform=iOS Simulator' build
```

Or open `ios/Awareness/Awareness.xcodeproj` in Xcode and run on a simulator or device.

**Note:** The iOS version uses local notifications to remind you to pause and breathe. When you tap a notification, the app opens and shows a full-screen blackout. The app must be granted notification permission on first launch.

### watchOS

The Apple Watch app is built as part of the iOS Xcode project:

```bash
cd awareness/ios/Awareness
xcodebuild -project Awareness.xcodeproj -scheme AwarenessWatch \
    -destination 'generic/platform=watchOS Simulator' build
```

Or open `ios/Awareness/Awareness.xcodeproj` in Xcode, select the `AwarenessWatch` scheme, and build for a watch simulator or paired device.

**Note:** The watch app works both standalone (without iPhone nearby) and as a companion. Settings sync automatically between iPhone and Apple Watch when both are available.

## Usage

After launching, a ☯ icon appears in the menu bar. Click it to:

- **See when the next blackout is scheduled**
- **Breathe now** — trigger an immediate blackout with your current settings
- **Snooze** — pause for 10 min, 20 min, 30 min, 1 hour, 2 hours, or indefinitely
- **Settings...** — open the configuration window
- **About Atempause...** — version info and credits

During a blackout:
- **ESC** (or **Cmd+Q** on macOS) dismisses early (unless Handcuffs mode is on)
- A higher-pitched gong sounds at the start
- A deeper gong sounds at the end
- The screen fades in and out over 2 seconds

## Settings

| Setting | Description | Default |
|---|---|---|
| Active hours | Time window for blackouts | 06:00 – 20:00 |
| Interval range | Min/max minutes between blackouts | 15 – 30 min |
| Duration range | Min/max seconds per blackout | 20 – 40 seconds |
| Visual mode | Plain black / custom text / image / video | Text ("Breathe.") |
| Start gong | Sound at blackout start | On |
| End gong | Sound at blackout end | On |
| Handcuffs mode | Prevent early dismissal | Off |
| Startclick confirmation | "Ready to breathe?" prompt before each break (macOS/Windows) | On |
| Apple Health (iOS/watchOS) | Log blackouts as Mindful Minutes | Off |
| Vibration (iOS) | Haptic feedback at start and end of blackout | Off |
| End flash (iOS) | White screen blink at end of blackout | Off |
| Start haptic (watchOS) | Taptic Engine feedback at blackout start | On |
| End haptic (watchOS) | Taptic Engine feedback at blackout end | On |

## Technical Details

### macOS

- **Swift** with **AppKit** + **SwiftUI**, built via Swift Package Manager or Xcode
- No third-party dependencies — only Apple frameworks (AppKit, SwiftUI, AVFoundation, CoreAudio, ServiceManagement)
- Three distribution channels: SPM dev build, Mac App Store (Xcode project with App Sandbox), direct distribution (Developer ID + notarization)
- Camera detection: `AVCaptureDevice.isInUseByAnotherApplication` (no TCC prompt)
- Microphone detection: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere`
- Overlay windows at `NSWindow.Level.screenSaver` with `canJoinAllSpaces`
- Settings persisted via `UserDefaults`; security-scoped bookmarks for user-selected files in the sandbox
- Version shown in About dialog is read dynamically from `CFBundleShortVersionString`
- Deployment target: macOS 13+

### Windows

- **C# .NET 8** with **WPF**, two NuGet dependencies (NAudio, Hardcodet.NotifyIcon.Wpf)
- Camera detection: registry `CapabilityAccessManager` (`LastUsedTimeStop == 0`)
- Microphone detection: NAudio WASAPI session enumeration
- Overlay windows: `Topmost`, `WindowStyle=None`, `AllowsTransparency` per monitor
- Keyboard suppression: `SetWindowsHookEx(WH_KEYBOARD_LL)` — no special permissions needed
- System idle detection: `PowerModeChanged`, `SessionSwitch`, `RegisterPowerSettingNotification`, screensaver polling
- Settings persisted as JSON in `%APPDATA%\Awareness\settings.json`
- Launch at Login via `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
- Version shown in About dialog is read dynamically from the assembly version
- Deployment target: Windows 10+

### iOS/iPadOS

- **Swift** with **SwiftUI**, standard Xcode project
- No third-party dependencies — only Apple frameworks (SwiftUI, AVFoundation, UserNotifications, PhotosUI, HealthKit)
- Uses local notifications (`UNUserNotificationCenter`) instead of background timers
- Pre-schedules 30 notifications at random intervals within the active time window
- Blackout presented as a full-screen cover when user taps notification
- Gong sounds play even in silent mode via `AVAudioSession(.playback)`
- Apple Health integration: each blackout is logged as Mindful Minutes via HealthKit (opt-in). First-launch prompt encourages enabling it.
- Haptic feedback: heavy impact at blackout start, success notification at end (opt-in)
- End flash: 1-second white screen blink before fade-out, visible through closed eyelids (opt-in)
- Settings persisted via `UserDefaults` (same as macOS)
- Supports both iPhone and iPad
- Version shown in home screen is read dynamically from `CFBundleShortVersionString`
- Deployment target: iOS 16+

### watchOS

- **Swift** with **SwiftUI**, part of the iOS Xcode project
- No third-party dependencies — only Apple frameworks (SwiftUI, WatchKit, UserNotifications, WatchConnectivity, HealthKit, WidgetKit)
- Uses local notifications (same 30-notification architecture as iOS) with default system sound
- `WKExtendedRuntimeSession(.mindfulness)` keeps the app alive during blackouts
- Haptic feedback via `WKInterfaceDevice` Taptic Engine (`.start` and `.success` types)
- Bidirectional settings sync with companion iPhone via `WCSession.updateApplicationContext()`
- Coordinated scheduling: iPhone pushes notification fire dates to the watch, keeping both devices in sync; falls back to random scheduling when standalone
- Bidirectional progress sync: practice stats merge between iPhone and Apple Watch using max() strategy
- Foreground notifications show a banner with sound — user must tap to start the blackout (no auto-triggering)
- WidgetKit complications for watch face: circular (☯ with status tint), rectangular (next blackout time), inline
- Shared code with iOS via target membership: models, settings, HealthKit, update checker, progress tracker
- Apple Health integration: same `HealthKitManager` logs mindful sessions on the watch
- Visual modes: plain black or custom text (no image/video on watch)
- Deployment target: watchOS 10+

## Credits

by [joergsflow](https://app.astrobin.com/u/joergsflow#gallery)

## License

[MIT](LICENSE)

---

*The goal of this app is to not need it anymore a little bit later.*

*Breathe. You are here.*
