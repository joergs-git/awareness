# Changelog

All notable changes to Atempause (formerly Awareness reminder), from initial release to the current version.

---

## v5.1.8

### macOS Tahoe Compatibility Fix
- **Fixed blackouts never triggering on macOS 26 (Tahoe)** — `CGEventSource.secondsSinceLastEventType` returns huge sentinel values for every event type when the process lacks Input Monitoring (sandboxed Mac App Store build on Tahoe). The user-idle gate (added in v5.0.3, partially fixed in v5.1.4 for Sequoia) was again suppressing every blackout. Fixed by ignoring values > 1 day and failing open: when idle info is unavailable, the blackout proceeds instead of being skipped indefinitely. macOS-only release; iOS / watchOS / Windows unchanged at 5.1.7

---

## v5.1.7

### Windows Feature Parity
- **Added "Skip breaks during audio/video calls" setting to Windows** — Windows now has the same toggleable camera/microphone skip detection as macOS. Previously Windows always skipped breaks during media use with no option to disable it. Default: off (matching macOS)
- **Version sync** — all platforms aligned to v5.1.7

---

## v5.1.6

### watchOS Complication Fix
- **Fixed yin-yang icon on physical Apple Watch** — regenerated the YinYang template PNG as an RGBA alpha-mask image. In watchOS vibrant rendering mode, only the alpha channel determines brightness (RGB is ignored). The bright half + bright dot use alpha 255 (full brightness), the dark half + dark dot use alpha 90 (~35% brightness). Template rendering mode in the asset catalog lets the system handle vibrant/accented tinting automatically

### watchOS Awareness Slider
- **Added 2-second grace period to the post-blackout awareness slider** — the auto-submit countdown no longer starts immediately, giving the user time to see and interact with the slider before it auto-dismisses

---

## v5.1.4

### Critical Bug Fix
- **Fixed blackouts never triggering on macOS 15 (Sequoia)** — `CGEventSource.secondsSinceLastEventType(.null)` is broken on macOS 15, always returning ~9600s regardless of actual user input. The user idle detection (added in v5.0.3) was skipping every blackout because macOS falsely reported the user as idle. Fixed by checking specific event types (mouseMoved, keyDown, leftMouseDown) and taking the minimum

---

## v5.1.3

### Bug Fix
- **Fixed blackout scheduling** — replaced blocking permission dialog with non-blocking system prompt. The modal alert could prevent the scheduler's timer from firing

---

## v5.1.2

### Release Build
- Version bump for App Store and direct distribution release

---

## v5.1.1

### watchOS Complication Fix
- **Black/white yin-yang** — replaced purple yin-yang complication icon with pure black/white version. Purple was washing out to plain white under the vibrant rendering mode on real watch faces; black/white provides maximum contrast that cannot desaturate further

---

## v5.1

### macOS Binary Renamed to "Atempause"
- **Product name change** — the macOS binary, app bundle, and Makefile output are now "Atempause" (matching the user-facing name already shown in menus and tooltips). Bundle identifier unchanged — no App Store impact

### New Setting: Skip Breaks During Audio/Video Calls (macOS)
- **Optional call detection** — new toggle "Skip breaks during audio/video calls" in Settings → Behavior. When enabled, breaks are suppressed while camera or microphone is active (e.g. during Zoom, FaceTime, Teams calls)
- **Default: off** — breaks interrupt regardless of media state, preserving the mindfulness-first philosophy. Users who want uninterrupted calls can opt in

### Startup Permission Check (macOS)
- **Accessibility prompt** — on every launch (direct distribution only), the app checks if Accessibility permission is granted. If not, a dialog explains why it's needed (keyboard suppression during breaks) and offers to open System Settings directly. Skipped in App Sandbox builds where the feature is disabled

---

## v5.0.4

### watchOS Complication Fix
- **High-contrast yin-yang** — replaced low-contrast purple-on-purple complication icon with high-contrast dark purple / light lavender version so the yin-yang shape remains visible on real Apple Watch faces (vibrant rendering mode desaturates to monochrome)

---

## v5.0.3

### User Idle Detection (macOS + Windows)
- **Skip breaks when away** — if no mouse/keyboard input for 5 minutes, blackout triggers are silently skipped (user is not at the screen)

### watchOS Complication Fix
- **Purple yin-yang complication** — watchOS complication now shows a proper two-tone purple yin-yang instead of monochrome

---

## v5.0.1

### watchOS Complication Fix
- **Fixed white circle complication** — watchOS yin-yang complication was rendering as a solid white circle due to `"original"` rendering intent; restored to `"template"` so the system renders a proper monochrome silhouette

---

## v5.0

### Purple Color Redesign (All Platforms)
- **Complete visual overhaul** — new purple color scheme replacing the previous warm/earthy Chinese sunrise palette
- **Purple yin-yang icons** — app icons, logos, tray icons all updated to deep purple / soft lavender tones
- **Adaptive backgrounds** — light mode: soft lavender gradient, dark mode: deep purple gradient
- **Updated accent colors** — donut charts, buttons, links, setup guide accents all use purple palette
- **Aquarelle backgrounds** — watercolor blobs updated to violet/lavender/plum tones
- **macOS menu bar** — custom colored purple yin-yang icon (larger, non-template)
- **Windows dark mode** — purple-tinted controls, borders, and backgrounds
- **AccentColor** set to purple in all iOS/watchOS/widget asset catalogs
- Readable in both light and dark mode across all platforms

---

## v4.1.2

### "Sleeping until" Display Fix (All Platforms)
- **Fixed misleading "next" time** — when the current time is outside the active time window, the app no longer displays a next break time that would never trigger
- **New "Sleeping until" indicator** — shows when the next active window starts (e.g. "Sleeping until 6:00 AM"), with moon icon on iOS and tooltip on macOS/Windows
- **Scheduler fix** — ForegroundScheduler (iOS) and BlackoutScheduler (macOS/Windows) no longer compute fire dates outside the active window; instead they sleep until the window reopens
- Localized in English and German on all platforms

---

## v4.1.1

### "Learn More" Wiki Link (All Platforms)
- **In-app wiki access** — "Learn More" button/link opens the project wiki in the user's language (EN or DE)
- **macOS**: third button in About dialog
- **iOS**: new row in About section with book icon
- **Windows**: new tray menu item "Learn More..." / "Mehr erfahren..."

### Localization Fixes (macOS/Windows)
- **Chart labels aligned** — awareness chart legend now uses "Focus Duration" / "Median" on all platforms (previously "range" / "median" on macOS/Windows, inconsistent with iOS)
- **5 missing German translations** added to macOS: "click anywhere to continue", "Startclick confirmation", startclick description, "Focus Duration", "Median"
- **Windows**: "range" → "Focus Duration" / "Bereich" → "Fokusdauer"

### Apple Health Default On (iOS/watchOS)
- **Fresh installs** now have Apple Health logging enabled by default

---

## v4.1

### Cross-Platform Pull Sync (macOS/Windows)
- **Desktop pulls remote events** — macOS and Windows now download blackout events from other platforms (iOS, watchOS) and integrate them into local progress statistics
- **Pull triggers** — app launch, wake from sleep, after each blackout
- **Deduplication** — processedEventIDs set (capped 5000) + lastPullDate cursor prevent double-counting
- **Unified stats** — progress view now reflects all devices, not just local activity

### Duration Trend Chart (All Platforms)
- **Session duration tracking** — records actual elapsed time for both completed and interrupted sessions
- **New chart** — dots for individual sessions + rolling 20-session moving average line in warm earthy palette
- **macOS/iOS**: SwiftUI chart in Progress view
- **Windows**: WPF Canvas-based chart in Progress window
- **watchOS**: duration data recorded and synced (compact display on small screen)
- **Backward-compatible** — old data without sessionDurations loads without issues

### Startclick Decline Sync Fix (macOS/Windows)
- **Declined confirmations now upload to Supabase** — "Not now" responses are recorded as completed=false so other platforms see the attempt
- **Root cause** — syncEventStartTimeISO was only set on confirm, not on show

### New Breathing Phrase (All Platforms)
- **"Slow down."** / **"Entdecke Langsamkeit."** — 6th rotating phrase added to the text-mode breathing break pool

---

## v4.0.2

### Supabase Sync Fix (All Platforms)
- **Fixed end record upload** — blackout completion with awareness score now reliably upserts to Supabase. Root cause: race condition in `flushPending()` and combined `Prefer` header parsing issue in PostgREST
- **Pre-formatted ISO 8601 timestamps** — start date string stored once and reused for end event, guaranteeing upsert match
- **Better error logging** — HTTP status codes logged on upload failures

### Always-Upload to Supabase (iOS)
- **Anonymous data upload** — iOS now uploads all events to Supabase even without desktop sync configured, using an auto-generated device UUID as fallback sync key
- **Privacy-compliant consent** — upload tied to Smart Guru toggle; footer explains anonymous data collection

### Supabase Online Status (iOS)
- **Connectivity indicator** — green/gray cloud icon + "Online"/"Offline" text in ContentView status section and SettingsView Desktop Sync section
- **Live check** — lightweight GET request to Supabase on app launch and foreground return

### Smart Guru: Awareness-Based Duration Adaptation (iOS)
- **Awareness score tracking** — `MindfulEvent` now captures the post-blackout awareness score for Smart Guru analysis
- **Adaptive duration algorithm** — when awareness scores consistently below 50%: decrease duration by random 3–8s (floor 6s). When stable for 3–8 breaths: hold, then increase by 1s per breath. On decline: go back 3–5s, hold for 2 days, then resume increases
- **Hourly awareness profiles** — EventStore tracks awareness scores per hour for future ML analysis
- **Deferred MindfulEvent recording** — completed blackouts wait for awareness score before creating the event, enabling score-aware Smart Guru evaluation

### Local Event Log (iOS)
- **Cross-platform event store** — new `LocalEventLog` persists all events from all platforms (iOS, macOS, Windows, watchOS) locally on iOS
- **90-day rolling window** — JSON file in documents directory with query methods for analytics

### watchOS Awareness Check Redesign
- **Volume-slider style bar** — replaces unusable Slider with a fillable horizontal bar supporting touch/drag and Digital Crown rotation
- **Auto-save after 2s** — no Done button needed; score submitted automatically after 2 seconds of inactivity
- **Applied to both paths** — in-view (BlackoutView) and alarm-overlay (ContentView)

### watchOS UX Improvements
- **Bigger "Breathe now" button** — increased font to `.callout`, more padding, fixed tap area collision with micro-task text

### iOS Progress Chart
- **Legend renamed** — "range"/"median" replaced with "Fokusdauer"/"Median" (multilingual EN/DE)

### Setup Guide / Einrichtungshilfe (iOS)
- **Two-stage onboarding** — brief intro on first launch (existing), detailed optimization guide after 3rd completed breath
- **7 guide sections**: Home Screen Widget, Lock Screen Widget, Apple Watch Complications (shown only when paired), Silence Distractions, Enable Notifications, Clean Home Screen, Refresh Notification Sounds
- **Cropped screenshots** — monochrome sepia-toned with soft blur, tap to expand numbered step-by-step navigation paths
- **Fully multilingual** — all text and steps translated EN/DE
- **Auto-hide after 2nd opening** — checkbox "Hide from main screen", moves to burger menu when hidden
- **Reopenable** — from burger menu and Settings (below Smart Guru)
- **Watch-aware** — Apple Watch section conditionally shown via `WCSession.isPaired`

---

## v3.18

### Awareness Slider (All Platforms)
- **Replaced Yes/Somewhat/No buttons** with a continuous awareness slider (0–100) — more nuanced self-assessment after each break
- **Slider saves on release** — no extra confirmation needed; default position at center (50)
- **Candlestick awareness chart** — replaces the three-bar chart with a stock-chart-style visualization: min–max wick, median dot, and trend line connecting medians across days
- **watchOS**: compact "Ø X%" median display + 7-day sparkline replaces the yes/somewhat/no circles
- **Backward compatible** — existing data with yes/somewhat/no is automatically migrated (yes→100, somewhat→50, no→0)

### Supabase Sync
- **Awareness score** now synced as numeric value (0–100) instead of "yes"/"somewhat"/"no"
- **Pull handles both formats** — old and new devices can coexist during rollout

---

## v3.17

### Bidirectional Cross-Platform Sync
- **iOS now uploads blackout events to Supabase** — desktop and watchOS can see when iOS had a break, preventing uncoordinated double-triggers
- **watchOS relays events to iOS** via WatchConnectivity (guaranteed delivery) — iOS uploads them to Supabase with source "watchos"
- **macOS and Windows pre-trigger check** — before firing a break, desktop queries Supabase for recent events from any other platform. If another device had a break within the minimum interval, the trigger is deferred
- **iOS pre-trigger check expanded** — now checks macOS, Windows, and watchOS events (previously desktop only)
- **Offline resilience on iOS** — pending upload queue (max 500, 7-day TTL) mirrors the desktop pattern

### Windows
- **ComboBox readability fix** — white background on time dropdowns in light mode settings (warm gradient no longer bleeds through)

---

## v3.16

### Cross-Platform Sync via Supabase
- **Desktop-to-iOS sync** — macOS and Windows upload blackout events (timestamp, duration, completion, awareness response) to Supabase. iOS pulls and integrates into local stats and Apple Health
- **Sync key** — iOS generates a 4-word + number passphrase (nature/zen themed). Enter it on your desktop app to link devices. SHA-256 hashed, anonymous, no account needed
- **Offline resilience** — pending events queue on desktop (max 500, 7-day TTL), auto-retry on launch and after each break
- **Deduplication** — 4 layers prevent double-counting: processed event IDs, last-pull cursor, concurrency guard, server-side unique constraint

### iOS/iPadOS
- **"I also work on a computer" toggle** in Settings — collapses the Desktop Sync section for a clean look when not needed
- **Generate / Copy / Regenerate sync key** — regenerate pulls latest data first and warns about re-entering on desktop

### macOS
- **Desktop Sync section** in Settings — text field for entering the sync passphrase from iPhone
- **Status indicator** — shows "Connected" when a valid sync key is configured

### Windows
- **Desktop Sync section** in Settings — checkbox to expand sync key input, matching macOS flow
- **Settings UI polish** — warm brown accent replaces Google Blue, clean text headers (no emoji), better spacing
- **Sync upload** — events uploaded after each blackout with offline queue fallback

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
