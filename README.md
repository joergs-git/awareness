# Awareness ☯

A mindfulness timer for macOS and Windows that randomly blacks out your screen for a few seconds, gently forcing you to pause, breathe, and return to the present moment.

## Why?

In the Vipassana meditation tradition, awareness (*sati*) is the foundation of all practice. The Buddha described it as the direct path to liberation: observing body, feelings, mind, and mental objects with clear comprehension, moment to moment, without clinging or aversion.

The challenge is that we spend hours each day staring at screens — answering emails, writing code, scrolling feeds — and gradually lose contact with ourselves. We forget to breathe deeply. We forget we even have a body. The mind narrows into a tunnel of tasks, and the day slips by on autopilot.

**Awareness** interrupts this pattern. A few times per hour, your screen gently fades to black. For 10, 20, or 30 seconds, there is nothing to do. You can close your eyes. Feel your breath. Notice your posture. Notice what your mind was just doing. Then the screen returns, and you continue — but now with a small gap of clarity inserted into your day.

This is not a break timer or a productivity tool. It is a practice aid. If you are walking the path of wisdom — whether through Vipassana, Zen, mindfulness-based practice, or simply a wish to be more present — these micro-interruptions become anchors of awareness threaded through your working day.

The Satipatthana Sutta teaches: *"A monk lives contemplating the body in the body, ardent, clearly comprehending, and mindful, having put away covetousness and grief for the world."* Awareness brings a tiny echo of that instruction into the digital workspace.

## Features

- **Menu bar / system tray app** — runs quietly with a ☯ icon, no Dock or Taskbar clutter
- **Random blackout intervals** — configurable min/max range (e.g. 15–30 minutes) so interruptions feel natural, not mechanical
- **Configurable duration** — 3 to 120 seconds per blackout
- **Smart detection** — automatically skips blackouts when your camera or microphone is in use (video calls, meetings)
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
- **Update checker** — checks GitHub for newer releases on startup and shows an "Update Available" menu item linking to the download page

## Installation

### macOS

#### Download (easiest)

1. Download the latest `Awareness.app.zip` from the [Releases](https://github.com/joergs-git/awareness/releases) page
2. Unzip and move `Awareness.app` to your `/Applications` folder
3. Double-click to launch

**Important — macOS Gatekeeper warning:**
Since this app is not signed with an Apple Developer certificate, macOS will show a warning the first time you open it:

> *"Awareness" can't be opened because Apple cannot check it for malicious software.*

To open it anyway:

1. **Right-click** (or Control-click) on `Awareness.app`
2. Select **"Open"** from the context menu
3. In the dialog that appears, click **"Open"** again

You only need to do this once. After the first launch, macOS remembers your choice and the app will open normally.

Alternatively, you can simply go to system settings "date privacy and security", scroll down to the end and click "Open anyway" button.
Or you can remove the quarantine flag via Terminal:
```bash
xattr -cr /Applications/Awareness.app
```

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

## Usage

After launching, a ☯ icon appears in the menu bar. Click it to:

- **See when the next blackout is scheduled**
- **Test Blackout** — trigger an immediate blackout with your current settings
- **Snooze** — pause for 10 min, 20 min, 30 min, 1 hour, 2 hours, or indefinitely
- **Settings...** — open the configuration window
- **About Awareness...** — version info and credits

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
| Duration | How long each blackout lasts | 20 seconds |
| Visual mode | Plain black / custom text / image / video | Text ("Breathe.") |
| Start gong | Sound at blackout start | On |
| End gong | Sound at blackout end | On |
| Handcuffs mode | Prevent early dismissal | Off |

## Technical Details

### macOS

- **Swift** with **AppKit** + **SwiftUI**, built via Swift Package Manager
- No third-party dependencies — only Apple frameworks (AppKit, SwiftUI, AVFoundation, CoreAudio, ServiceManagement)
- Camera detection: `AVCaptureDevice.isInUseByAnotherApplication` (no TCC prompt)
- Microphone detection: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere`
- Overlay windows at `NSWindow.Level.screenSaver` with `canJoinAllSpaces`
- Settings persisted via `UserDefaults`
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

## Credits

by [joergsflow](https://app.astrobin.com/u/joergsflow#gallery)

## License

[MIT](LICENSE)

---

*The goal of this app is to not need it anymore a little bit later.*

*Breathe. You are here.*
