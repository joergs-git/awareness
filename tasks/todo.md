# v4.0 — Supabase Fix, Smart Guru Awareness, Setup Guide, Always-Upload

## (b) Fix End Record Upload (All Platforms)
- [x] Fix Prefer header — separate addValue calls
- [x] Store formatted ISO 8601 date at start, reuse for end
- [x] Add recordEventRaw to SyncManager
- [x] Remove flushPending race condition
- [x] Upload completed=true before awareness check as fallback
- [x] Apply same fixes to macOS and Windows

## (b2) watchOS Volume-Slider Awareness Check
- [x] Create WatchAwarenessBar with fillable bar + Digital Crown
- [x] Auto-save after 2s inactivity
- [x] Apply to BlackoutView and ContentView overlay

## (b3) watchOS Bigger Breathe Now Button
- [x] Increase font and padding
- [x] Fix contentShape tap area collision

## (a) Supabase Online Status on iOS
- [x] Add checkConnectivity to SupabaseClient
- [x] Make SyncManager ObservableObject with isSyncOnline
- [x] Show in ContentView and SettingsView

## (e) Always Upload to Supabase
- [x] Auto-generate device UUID in SyncKeyManager
- [x] Modify hashedSyncKey fallback
- [x] Guard on smartGuruEnabled
- [x] Update Smart Guru footer with privacy disclosure

## (c) Local Event Log
- [x] Create LocalEventLog.swift
- [x] Integrate in SyncManager and BlackoutView
- [x] Add to pbxproj

## (d) Smart Guru Awareness-Based Duration
- [x] Add awarenessScore to MindfulEvent
- [x] Extend AdaptiveState with awareness fields
- [x] Add hourAwarenessProfile to EventStore
- [x] Implement evaluateAwarenessDurationAdaptation in SmartGuru
- [x] Defer MindfulEvent recording for completed blackouts

## (f) Setup Guide / Einrichtungshilfe
- [x] Create SetupGuideView with 7 guide sections
- [x] Cropped monochrome screenshots with step-by-step paths
- [x] Auto-hide after 2nd opening, checkbox toggle
- [x] Prominent on main screen, moves to burger menu when hidden
- [x] Also accessible from Settings
- [x] Watch-aware (isPaired conditional)
- [x] Full EN/DE translations
- [x] Notification sounds refresh guide section

## Version Bump + Docs
- [x] All 4 files bumped to 4.0 / 4.0.0
- [x] CHANGELOG.md updated
- [x] lessons.md updated

## Results
All tasks completed. macOS SPM, iOS (+ watchOS + widget) all build successfully.

---

# Future Tasks

## Android Version
- [ ] Kotlin + Jetpack Compose, mirror iOS architecture
- [ ] Foreground timer (Handler.postDelayed) + 30 pre-scheduled notifications (AlarmManager)
- [ ] Full-screen blackout Activity (no system overlay)
- [ ] Settings, progress tracking, practice cards, localization (EN/DE)
- [ ] Health Connect integration (mindful minutes)
- [ ] Supabase sync (Kotlin SDK)
- [ ] Notification actions: "Start Breathing" + "Snooze 30 min"
