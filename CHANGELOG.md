# Changelog

All notable changes to Awareness reminder, from initial release to the current version.

---

## v2.16

### iOS: Foreground scheduler (Apple Guideline 4.5.4 compliance)
- **App now works without notification permission** — a new in-app foreground timer triggers blackouts automatically while the app is open, so the core experience is fully functional even if the user denies notifications
- **Notifications become optional** — soft blue info message explains notifications are only needed for background reminders; status shows "Active (foreground only)" when notifications are denied
- **Dedup logic** — foreground timer and notification system coexist without double-triggering (60s lookahead for notifications, 30s lookback for foreground triggers)
- **"How It Works" text updated** — steps now describe the general experience instead of referencing notifications specifically

---

## v2.15

### All platforms: "Breathe now" button rename
- **"Test Blackout" → "Breathe now"** — the manual breathing button is not a test, it's a real mindful moment. Renamed across macOS, iOS, watchOS, and Windows (DE: "Jetzt atmen")

### macOS, iOS/iPadOS, Windows: Image breathing animation
- **Images now breathe** — custom images and the default image pulse gently during blackout (scale 0.95↔1.06, opacity 0.6↔1.0, 3s cycle), matching the text mode animation. Windows also gains the text breathing animation it was previously missing. (watchOS does not support image mode.)

### watchOS: Namaste after alarm dismiss
- **Namaste now visible after alarm dismiss** — when the alarm end-signal fires with the wrist down, watchOS shows a system alarm UI that covers the app. Previously the 🙏 namaste rendered behind it and was invisible. Now the namaste is shown in ContentView after the user taps "Stop", ensuring they always see the closing gesture

---

## v2.14

### watchOS: Blackout display & end-signal reliability
- **Alarm session end signal** — uses `WKExtendedRuntimeSession` in alarm mode with `notifyUser(hapticType:repeatHandler:)` to deliver haptic feedback at the exact blackout end time, even when the wrist is down and display is off (the only API capable of this)
- **Backup notification** — local notification scheduled as fallback end signal
- **Extended display-on time** — breathing animation wrapped in `TimelineView(.animation)` to signal continuous rendering need to watchOS

### watchOS: 3-signal audio/haptic system
- **New reminder haptic** — 2× `.failure` pulses when a notification arrives, nudging the user to pay attention (opt-in via "Reminder haptic" toggle)
- **Synthesized start chime** — double chime (440Hz → 660Hz) generated in real-time via `AVAudioEngine`; always plays, respects watchOS silent/mute mode (`.ambient` audio session)
- **New end haptic** — 2× `.directionUp` pulses (changed from 4× `.notification`) for an uplifting "all done" signal
- Settings migration: `hapticStartEnabled` auto-migrates to `reminderHapticEnabled`

### macOS: Startclick confirmation
- Optional **"Ready to breathe?"** prompt before each blackout — decline to skip without affecting your statistics
- New toggle in Settings → Behavior (default: off)

### macOS: Auto-resume on wake
- Returning from **sleep or screen lock** while snoozed now **auto-clears the snooze** and restarts the scheduler
- No more manually clicking "Resume" after waking up your Mac

---

## v2.13

### Mindful terminology (all platforms)
- Renamed "Progress" to **Mindful Moments** and "Success Rate" to **Discipline** across macOS, Windows, iOS, and watchOS
- German: "Fortschritt" → **Achtsamkeitsmomente**, "Erfolgsquote" → **Disziplin**

### iOS header redesign
- New spiritual header layout: "Mindfulness in Action" / "Achtsamkeit im Tun" above the logo, followed by "In stillness rests the strength" / "In der Stille ruht die Kraft"

### Bug fix
- Fixed HealthKit prompt showing on every app launch — now appears only once and is permanently dismissed with either "Enable" or "Not Now"

---

## v2.12

### Breathing animation (all platforms)
- Text mode: gentle pulsating scale and opacity on a 3-second breathing cycle
- Plain black mode: subtle breathing circle as a minimal visual anchor
- Helps keep the watchOS display active on Always-On Display watches

### watchOS: Fix blackout suspension
- Added `WKBackgroundModes: mindfulness` and `ExtendedSessionDelegate` so the app stays alive when the wrist drops
- End haptics, flash, and namaste now fire on time instead of queuing until wrist-raise
- Fixed instant dismissal on devices where the extended runtime session couldn't start

### Progress tracking fix
- Notifications are now counted as "triggered" when delivered, not when the blackout starts
- Ignored notifications correctly show as missed (e.g. "7 of 12" instead of "7 of 7")

### macOS: Fix input capture during blackout
- Force app activation when blackout starts so ESC and clicks are properly detected
- Added global mouse monitor as fallback when another app steals focus

---

## v2.1

- **iOS is now the master scheduler** — eliminates potential sync loops between iPhone and Apple Watch; the watch adopts iOS fire dates when available, only schedules independently as fallback
- **macOS blackout dismiss fixed** — ESC key now properly dismisses the blackout when handcuffs mode is off; mouse click anywhere on the overlay also dismisses
- **End flash on by default** — the white end-of-blackout flash (visible through closed eyelids) is now enabled by default on iOS and watchOS
- **Reversed watchOS haptic signals** — gentle success pulses invite you into the blackout, stronger notification pulses signal the end
- **Sync loop prevention** — debounced observers on both iOS and watchOS now use timestamp-based cooldowns to prevent echo pushes after receiving remote context

---

## v2.0

- **Renamed to "Awareness reminder"** for clarity across all platforms
- **Coordinated scheduling fix** — earliest-wins negotiation keeps iPhone and Apple Watch in perfect sync
- **Namaste confirmation** after each completed blackout on iOS (already on watchOS)
- **Enhanced haptic patterns on Apple Watch** — distinctive multi-tap start and end feedback
- **Progress display** now shows completed/triggered (completed first) on all platforms
- **Inline progress counter** on watchOS home screen
- **Date-based watchOS timer** — prevents energy-saver mode from extending blackout duration
- **Recurring HealthKit prompt** on iOS — gently reminds to enable Apple Health if not yet active
- **New defaults** — active window 6am–10pm, blackout duration 20–40s
- **Safety reschedule** when dismissing settings on iOS

---

## v1.6

- **Reordered menus across all platforms** — Progress (now Mindful Moments) is directly below the status line, followed by Snooze, then actions. Consistent order on macOS, Windows, iOS, and watchOS.

---

## v1.5

- **Active touch blackouts** (iOS/watchOS) — notifications now require a tap to start the blackout; no more auto-triggering when the app is in the foreground
- **Coordinated scheduling** — iPhone generates notification times and syncs them to Apple Watch, so both devices stay in harmony
- **Cross-device progress sync** — practice stats merge between iPhone and Apple Watch via WatchConnectivity
- **Namaste confirmation** (watchOS) — a brief namaste shown after each completed blackout

---

## v1.4

- **Progress tracking** — donut chart showing today's completion, lifetime statistics, and a 14-day bar chart history (all platforms)
- **Localization** — full English and German (EN/DE) language support (all platforms)

---

## v1.3

- **Apple Watch app** — standalone and companion support with WatchConnectivity sync
- **WidgetKit complications** — accessoryCircular, accessoryRectangular, and accessoryInline for the watch face
- **Haptic feedback** on watchOS — Taptic Engine pulses at blackout start and end
- **Extended runtime session** keeps the watch app alive during blackouts

---

## v1.2

### iOS/iPadOS
- **HealthKit encouragement** — on first launch, a prompt asks if you'd like to log mindful pauses to Apple Health
- **Haptic vibration** — heavy impact at blackout start, gentle success haptic at end (opt-in)
- **End flash** — 1-second white screen blink at end of blackout, visible through closed eyelids (opt-in)
- **Feedback section** — sound settings renamed to "Feedback" to group gong, vibration, and flash options

### All platforms
- **App Store distribution** — macOS Xcode project for Mac App Store with App Sandbox and security-scoped bookmarks
- **Direct distribution** — Developer ID signing + notarization support via `make release-direct`
- **HealthKit integration** — iOS logs each blackout as Mindful Minutes in Apple Health (opt-in)
- **Improved iOS notifications** — rich notifications with mindfulness prompts, action buttons, and custom gong sound
- **Dynamic version display** — About dialogs read version from bundle/assembly instead of hardcoded strings

---

## v1.1

- **Update checker** — the app checks GitHub for newer releases on startup. If an update is available, an "Update Available" menu item appears linking directly to the releases page.

---

## v1.0

Initial release — macOS + Windows.

- Menu bar / system tray app with yin-yang icon
- Random blackout intervals (configurable 1–120 min range)
- Blackout duration 3–120 seconds with 2-second fade transitions
- Visual modes: plain black, custom text, image, or looping video
- Start gong + end gong (independently toggleable)
- Camera/microphone detection — skips blackouts during calls
- Handcuffs mode — commit to the full duration
- Snooze (10 min – 2 hours, or indefinitely)
- Keystroke suppression during blackout (macOS: Accessibility, Windows: low-level keyboard hook)
- Multi-monitor support
- Launch at Login
- Persistent settings (UserDefaults on macOS, JSON on Windows)
