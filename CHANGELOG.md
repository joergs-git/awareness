# Changelog

All notable changes to Atempause (formerly Awareness reminder), from initial release to the current version.

---

## v3.15

### Windows Feature Parity
- **Post-breathing awareness check** — "Were you there?" with Yes/Somewhat/No, matching macOS/iOS/watchOS
- **Practice cards & micro-tasks** — 7 cards with 58 micro-tasks, daily rotation, shown after each breathing moment
- **Startclick confirmation** — optional "Ready to breathe?" prompt before each break (setting + UI)
- **Twin donut charts** — Today + Lifetime with brush-stroke style in warm earthy palette
- **Awareness response chart** — 14-day yes/somewhat/no bar chart in progress window
- **Breathing circle** — subtle pulsing dot in plain-black mode
- **Snooze auto-clear on wake** — snooze now resets when returning from sleep/lock (matches macOS)
- **Monitor hot-plug** — overlay windows adapt when displays are connected/disconnected during a break
- **Default blackout range** fixed — fresh installs now default to 20–40s (was 20–20s)

### iOS/iPadOS
- **Logo rotation** — yin-yang logo slowly rotates counterclockwise (1 revolution per minute)
- **Logo pulse fix** — breathing pulse animation now reliably starts on both logo and "Breathe now" button

### watchOS
- **Double awareness check fix** — alarm race condition resolved; "Were you there?" now appears exactly once

---

## v3.14

### Awareness Check — "Were you there?"
- **Post-breathing awareness question** — after each completed breathing moment, a quick check appears: "Were you there?" with three answers: Yes / Somewhat / No (iOS, watchOS, macOS)
- Responses tracked per day and synced between iOS and watchOS
- 14-day awareness response chart replaces the old self-report counters in the progress view

### UI Simplification
- **Removed manual self-report counters** (checkmark/eye/circle icons) from practice card banners on iOS and watchOS
- **Removed header slogans** ("Mindfulness in Action" / "In der Stille ruht die Kraft") from iOS — just the yin-yang logo
- **Collapsible lower sections** on iOS — status, progress, snooze, actions, about are hidden behind a subtle toggle to keep focus on breathing
- **Consolidated layout** — practice card, inspiration, and breathe button form one tight visual unit on iOS and watchOS

---

## v3.13

### App Rename: Atempause
- **Renamed from "Awareness reminder" to "Atempause"** across all platforms (macOS, iOS/iPadOS, watchOS, Windows)
- Display name, notifications, tooltips, menu items, App Store metadata, and AltStore source all updated
- Bundle IDs unchanged — seamless update for existing users, no data loss

---

## v3.12

### macOS: App Store Compliance
- **Removed Accessibility usage** — CGEvent tap (keystroke suppression) is now skipped in sandboxed Mac App Store builds, resolving Apple guideline 2.4.5
- Added settings and menu bar screenshots for App Store listing (EN/DE)

### AltStore Sideloading
- **AltStore source** — iOS app now available for sideloading via AltStore (`altstore/apps.json`)

---

## v3.11

### iOS: Smart Call Detection
- **Skip during calls** — breaks are automatically skipped when on a phone or video call (FaceTime, Zoom, Teams, WhatsApp, and any CallKit-integrated app)
- Skipped breaks are **not counted as triggered** — discipline statistics stay accurate
- New toggle in Settings → Behavior: "Skip during calls" (default: on)
- Works for both foreground timer and notification-triggered breaks

### macOS: App Store Screenshots
- Added screenshot generator script for macOS App Store (blackout + progress views, EN/DE)

---

## v3.10

### All Platforms: Localized Breathing Phrases
- **Language-aware rotation** — rotating breathing phrases now follow device language instead of being multilingual
- English: "Breathe.", "You are here.", "Nothing to do.", "Just breathe.", "This moment."
- German: "Atme.", "Du bist hier.", "Nichts zu tun.", "Nur atmen.", "Dieser Moment."

---

## v3.09

### All Platforms: Rotating Breathing Phrases
- **Random text rotation** — default text-mode breaks now cycle through 5 phrases ("Breathe.", "You are here.", "Nichts zu tun.", "Nur atmen.", "This moment.") to prevent habituation
- Custom text is unaffected — rotation only applies when using the default "Breathe." setting

### iOS: UI Polish
- **Yin-yang logo pulse** — home screen logo now breathes in sync with the "Breathe now" button
- **Logo tap to breathe** — tapping the yin-yang icon triggers a breathing break
- **Vibration default ON** — fresh installs now default to vibration enabled

### watchOS: Tap Target Fix
- **Micro-task tap** — tapping the micro-task box below the practice card now opens the card detail sheet

### All Platforms: Settings Philosophy Footer
- **Closing thought** — settings screen ends with "The goal of this app is to not need it anymore. Until then: Breathe." (EN/DE)

---

## v3.08

### All Platforms: Unified Warm Background
- **Adaptive warm gradient** — cream-to-tan in light mode, warm charcoal in dark mode; applied to all main views (ContentView, Settings, Progress) on iOS, watchOS, and macOS
- **Windows dark mode support** — settings and progress windows detect `AppsUseLightTheme` registry key and switch gradient accordingly
- **iOS widget adaptive** — home screen widget background now respects dark mode instead of forcing light scheme

### All Platforms: Rename "Blackout" → "Breathing break" / "Atempause"
- All user-visible strings renamed from "Blackout" to "Break" (EN) / "Atempause" (DE) across iOS, watchOS, macOS, and Windows localization files
- Code identifiers unchanged — only UI-facing text updated

### iOS: App Store Rating Prompt
- **Milestone-based review requests** — `SKStoreReviewController.requestReview(in:)` triggers at 30, 50, and 100 completed breaks
- Each milestone fires once; Apple's built-in rate-limiting applies on top

### macOS: App Store Rating Prompt
- Same milestone logic (30/50/100); only triggers in sandboxed (App Store) builds

### iOS: First-Launch Onboarding
- **Single-screen onboarding** — warm gradient, ☯ symbol, brief instruction text, "Start" / "Los geht's" button
- Shown once via `hasLaunchedBefore` flag in SettingsManager

### All Platforms: Visual Polish
- **Stronger "Breathe now" pulse** — scale range increased from 6% to 12% for more noticeable animation
- **Monochrome namaste 🙏** — `.grayscale(1.0).opacity(0.7)` applied to end-of-breathing emoji on macOS, iOS, and watchOS

---

## v3.07

### watchOS: UI Overhaul & Feature Parity
- **Compact layout** — status bar and practice card merged into a single row with zero gap; "Breathe now" visible without scrolling on 49mm Ultra
- **Full card title** — shows `localizedTitle` (up to 2 lines, centered) instead of short title
- **Inline micro-task** — tinted rounded box below the card with colored connector, matching iOS style
- **☯ breathe shortcut** — large monochrome yin-yang icon on the card row triggers a blackout directly
- **Tap card to open detail** — tapping anywhere on the card background (not just the title) opens the full-screen detail sheet
- **Double-tap to decrement** — self-report counters support double-tap to undo accidental increments
- **Toned micro-task in detail** — card detail sheet shows micro-task with tinted rounded background
- **Practice tracking stats** — ProgressView shows today's succeeded/noticed/forgot counters in a "Situations" section

---

## v3.06

### iOS: UI Polish & Practice Tracking Chart
- **Compact header** — motto text moved above yin-yang icon, tighter vertical spacing throughout
- **Breathing pulse on "Breathe now" button** — gentle 3s scale + opacity animation to encourage tapping
- **Merged status & progress section** — status dot + next time and Mindful Moments in one headerless section; single donut with counter inside, 🙏 monochrome icon
- **Card banner redesign** — title centered with full width (2 lines), self-report counters moved below; double-tap to decrement (undo accidental taps)
- **Micro-task tinted background** — light fill matching card color instead of plain border
- **Practice tracking bar chart** — new 14-day "Situations" chart in Mindful Moments showing succeeded/noticed/forgot counters alongside the existing "Breathings" chart
- **Compact list section spacing** — `.listSectionSpacing(.compact)` on iOS 17+ for tighter layout

---

## v3.05

### iOS: Lock Screen Widgets
- **Three lock screen widget families** — circular (donut progress ring with ☯ + counter), rectangular (card title + next time + counter), and inline (text-only: "☯ 3/5 · Letting Go")
- Lock screen widgets use system-tinted monochrome rendering (no custom colors)

---

## v3.04

### iOS: Widget Styling
- **Seamless widget background** — sunrise gradient now fills the entire widget rounded rect via `containerBackground` (iOS 17+), eliminating the visible box-within-a-box appearance. Content uses full available space.

---

## v3.03

### macOS: Practice Cards & Micro-Tasks
- **Daily practice cards** — each day a random mindfulness card (from the same 7-card deck as iOS) is assigned. Card title and micro-task are shown after each breathing session.
- **Post-blackout flow** — after the breathing timer ends: namaste 🙏 (1.5s) → card title + random micro-task on the black screen → click anywhere to dismiss. Early dismiss during breathing skips the card phase entirely.
- **Micro-task rotation** — each completed blackout picks a fresh random micro-task from today's card pool (avoids last 3 for variety).

### macOS: Twin Donut Charts
- **Two donuts side by side** — "Today" and "Overall" discipline charts in the Mindful Moments window, matching the iOS brush-stroke style with warm earthy color.

### All Platforms: Micro-Task Rotation
- **New task after every blackout** — iOS, watchOS, and macOS all rotate to a new random micro-task after each completed blackout session (instead of showing the same task all day).

---

## v3.02

### iOS: Micro-Task Auto-Assign
- **Micro-task visible from launch** — today's micro-task now appears immediately when the app opens, not just after the first blackout. Auto-assigns from today's card pool on first access.
- **Removed post-blackout overlay** — micro-task reveal animation after blackout removed; the task is always visible in the main list instead.

### iOS: Home Screen Widget
- **New systemSmall + systemMedium home screen widgets** — glance at today's practice card, micro-task, progress donut, and next blackout time without opening the app
- **Widget deep link** — tap the widget to open the app and trigger a blackout (`awareness://breathe` URL scheme)
- **WidgetDataBridge** — lightweight data bridge pattern writes a Codable snapshot to App Group shared UserDefaults; widget reads it independently without sharing SettingsManager
- **Auto-refresh** — widget updates on app launch, foreground return, blackout completion, snooze, and resume
- **App Group** `group.com.joergsflow.awareness.ios` shared between iOS app and widget extension

---

## v3.0

### All platforms: Smart Guru — Adaptive Mindfulness Scheduling
- **Smart Guru algorithm** — rule-based adaptive system that learns your rhythm over a 3-day baseline, then adjusts intervals (±10%) and blackout duration based on your behavior. Thriving users get more frequent, longer pauses; struggling users get gentler pacing
- **Duration adaptation** — automatically shortens blackout duration by 5s after 3+ consecutive dismissals; gradually increases by ~1s/day when you're consistently completing (85%+ rate over 7 days)
- **Toggle in Settings** — enable/disable Smart Guru; when active, manual interval and duration sliders are replaced with read-only adaptive info

### iOS/iPadOS + watchOS: Practice Cards & Micro-Tasks
- **7 daily practice cards** — each day you receive a mindfulness assignment from a card deck (Letting Go, Non-Intervention, Undivided Perception, Unhurried Response, Intentionlessness, Daily Presence, Silence), each with its own color and philosophical background
- **Short titles** — compact card names for watchOS and banner displays (e.g. "Loslassen" instead of "Übung des Loslassens")
- **66 micro-tasks** — concrete everyday situations linked to each card where you can practice the day's principle (e.g. "Notice the urge to check for a reply. Don't check. Just notice the urge.")
- **Morning notification** — daily practice card delivered at a configurable hour (default: 07:00)
- **Self-report counters** — three tap-to-increment icons on the card banner: succeeded (✓), noticed (◐), forgot (○) — track your practice throughout the day
- **Aquarelle backgrounds** — organic watercolor-style visuals for card and task presentation (layered blurred gradients in warm earth tones)

### iOS/iPadOS + watchOS: Progress View Redesign
- **Two donuts side by side** — "Today" (midnight-to-midnight) and "Overall" (lifetime) discipline charts
- **Brush-stroke style** — earthy indigo-slate color with overlapping semi-transparent arcs simulating ink brush texture
- **Philosophical slogans** — 19 contemplative quotes that adapt to your performance: deep koans when thriving, ironic-philosophical wit when struggling, neutral wisdom when no data

### iOS/iPadOS: Event-Level Logging
- **MindfulEvent tracking** — every blackout outcome (completed, dismissed, ignored) is recorded with timestamp, duration, and context
- **90-day rolling window** — EventStore with hourly and weekday profile tracking for long-term pattern analysis
- **DailySelfReport archiving** — practice card feedback preserved for future analysis

### watchOS: Enhanced Complications & UI
- **Progress counter on circular complication** — yin-yang icon shows today's progress (e.g. "2/5") as an overlay
- **New practice card complication** — rectangular complication showing today's card title and current micro-task
- **WidgetBundle** — two complication types available: status (circular/rectangular/inline) and practice card (rectangular)
- **Compact status bar** — green/orange dot + next time + progress counter on a single line, replacing verbose status text
- **Self-report on watch** — tap counters directly on the practice card section with haptic feedback

### Localization
- All new strings localized in English and German (slogans, card titles, descriptions, prompts, micro-tasks, settings labels, guru status messages)

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
