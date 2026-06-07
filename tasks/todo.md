# v5.2 — Smart Guru Re-Aim, Manual Daily Card, Per-Card Photos

## (a) Smart Guru — fix goal misalignment (iOS only)
- [x] A1: `.ignored` out of frequency signal — add `EventStore.engagedSuccessRate`, hold when no engaged events
- [x] A1: stop counting `.ignored` into hourProfile (record)
- [x] A2: unify two duration controllers → single `adjustDuration` (one step max, no stacking)
- [x] A3: low awareness HOLDS (no shrink); shrink only on ≥3 consecutive dismissals; floor 6s→12s
- [x] A4: remove down-bias; add gentle goal-directed upward drift in comfort zone; status text shows lengthening
- [x] A5: interval floor 5→8 min
- [x] A6: remove dead code (weekdayProfile, hourAwarenessProfile, streakIgnored + awareness-spiral state fields)
- [x] Parse-check Swift clean (full iOS build blocked: iOS 26.5 platform not installed in this env)

## (b) Manual daily card + cross-device consistency
- [x] B1: deterministic date-seeded rotation (index = daysSinceEpoch % 7) — iOS/macOS/Windows
- [x] B2: manualCardSelectionEnabled + manualCardID settings + 7-card picker UI (iOS/macOS/Windows)
- [x] B3 (partial): iOS↔watch connectivityContext carries manual selection; full desktop sync rides C2 manifest
- [x] macOS verified via `swift build`; iOS parse-clean; Windows can't build in this env (WPF)

## (c) Per-card photos (front/back) + Supabase Storage opt-in
- [x] C1: per-card front/back photo storage (iOS Documents, macOS App Support, Windows %APPDATA%)
- [x] C2: Storage client up/download/list + CardAssetSync (push union model + pull) + cardPhotoSyncEnabled opt-in; SQL migration in supabase/card-assets-bucket.sql (user runs in Supabase web console)
- [x] C3: cardPhoto visual mode + end-of-break CardFlipView (page-turn 3D, tap flip, ✕ top-left close); phrase fallback; watchOS text-only (no exhaustive switch — unaffected)
- [x] macOS verified via swift build; iOS parse-clean; Windows via GitHub Actions

## Finalize
- [x] Version bump → 5.2 (macOS Info.plist+pbxproj, iOS pbxproj ×8, Windows 5.2.0) + CHANGELOG.md
- [x] Security/privacy review (no secrets, opt-in default off, private bucket, no stray files)
- [ ] Commit on feature/guru-cards-photos
- [ ] iOS/Windows builds on a configured machine; run supabase/card-assets-bucket.sql; Apple archive/notarize per policy

## Results
- Phase A (Smart Guru) + B (manual card/rotation) + C (card photos + opt-in Supabase Storage sync) implemented on iOS/macOS/Windows.
- Build-verified: macOS `swift build` ✓; full iOS scheme (iOS + watchOS + widgets, OS 26.5) **BUILD SUCCEEDED** ✓; watchOS scheme (OS 26.4) **BUILD SUCCEEDED** ✓. No fixes were needed. Windows builds via GitHub Actions.
- User-side remaining: create the Supabase bucket via supabase/card-assets-bucket.sql (the MCP-connected Supabase account does not include the awareness project); push/merge; Apple archive + notarize per policy.

---

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

# v5.1.8 — macOS Tahoe Compatibility Hotfix (2026-05-01)

## CGEventSource idle-gate fix
- [x] Diagnose: idle gate suppresses every blackout on macOS 26 (Tahoe) sandbox build
- [x] Patch `BlackoutScheduler.timerFired()` to fail open on sentinel/unavailable values
- [x] Bump macOS version 5.1.7 → 5.1.8, build → 1
- [x] CHANGELOG.md entry
- [x] tasks/lessons.md entry (fail-open rule)
- [x] Verify `swift build` succeeds
- [x] Commit + push
- [x] `make release-direct` — notarize + staple
- [x] GitHub release with notarized ZIP

## Open
- [ ] Mac App Store: Xcode archive + upload to App Store Connect (needs interactive Xcode or app-specific password)
- [ ] Verify on a Tahoe machine when one is available

## Results
macOS-only release. iOS / watchOS / Windows intentionally not bumped — they aren't affected by this regression.

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
