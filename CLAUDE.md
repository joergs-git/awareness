# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Awareness** is a macOS menu bar app — a mindfulness/breathing timer that randomly blacks out the screen for a few seconds, forcing the user to pause, breathe, and reset. A vipassana timer for computer work.

Repository: https://github.com/joergs-git/awareness
License: MIT

## Build & Run

```bash
make run          # build + bundle + launch
make bundle       # build + bundle only (output: build/Awareness.app)
make clean        # remove build artifacts
swift build       # compile only (no .app bundle)
```

Requires macOS 13+, Xcode Command Line Tools, Swift 5.9+.

## Architecture

- **Swift Package Manager** project (`Package.swift`, swift-tools-version 5.9)
- **AppKit** for menu bar + overlay windows, **SwiftUI** (hosted via `NSHostingView`) for settings UI and blackout content
- **No third-party dependencies** — only Apple frameworks (AppKit, SwiftUI, AVFoundation, CoreAudio, ServiceManagement)
- `Makefile` assembles the `.app` bundle (copies binary + Info.plist + AppIcon.icns + resources, ad-hoc codesign)
- `SupportFiles/Info.plist` — `LSUIElement=true` (menu bar only, hidden from Dock)

## Project Structure

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

## Key Technical Decisions

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

- The app icon is `SupportFiles/AppIcon.icns` (yin-yang design), referenced via `CFBundleIconFile` in Info.plist
- Resources are bundled via SPM `.copy("Resources")` and accessed at runtime via `Bundle.module`
- The global event tap for keystroke suppression requires Accessibility permission — degrades gracefully if not granted
- Settings migration: old `gongEnabled` key is auto-migrated to `startGongEnabled` + `endGongEnabled`
