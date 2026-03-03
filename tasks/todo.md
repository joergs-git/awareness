# v3.02 — Fix Micro-Task Display + iOS Home Screen Widget

## Task A: Fix iOS Micro-Task Display

- [x] A.1 Change `currentMicroTask()` to auto-assign if no task exists for today
- [x] A.2 Remove `microTaskShownToday` gate from ContentView line 69
- [x] A.3 Remove post-blackout overlay state vars, modifier, and function
- [x] A.4 Simplify `handlePostBlackout()` — remove micro-task reveal logic

## Task B: iOS Home Screen Widget

- [x] B.1 Create WidgetDataBridge.swift (iOS app target)
- [x] B.2 Add App Group entitlement to iOS app
- [x] B.3 Create AwarenessWidget directory + all files (bundle, provider, Info.plist, assets)
- [x] B.4 Create widget extension entitlements
- [x] B.5 Add widget target to pbxproj (E50099, A5/B5/C5/D5/E5/F5 IDs)
- [x] B.6 Add WidgetDataBridge.swift to iOS Sources phase
- [x] B.7 Create Info.plist for URL scheme (awareness://)
- [x] B.8 Add INFOPLIST_FILE to iOS build configs
- [x] B.9 Add .onOpenURL handler in AwarenessApp.swift
- [x] B.10 Add updateWidget() calls in ContentView + AwarenessApp

## Version Bump

- [x] C.1 SupportFiles/Info.plist → 3.02
- [x] C.2 Awareness.xcodeproj/project.pbxproj → 3.02 (2 configs)
- [x] C.3 ios/Awareness/.../project.pbxproj → 3.02 (all configs)
- [x] C.4 windows/Awareness/Awareness.csproj → 3.02.0
- [x] C.5 CHANGELOG.md — add v3.02 entry

## Documentation

- [x] D.1 Update CLAUDE.md (project structure, technical decisions, version bump table)
- [x] D.2 Update memory/MEMORY.md

## Verification

- [x] E.1 Build iOS target — BUILD SUCCEEDED (all targets: iOS + watchOS + widget)

## Results

All tasks completed. iOS and widget extension build successfully.
New files: WidgetDataBridge.swift, AwarenessWidgetBundle.swift, AwarenessWidgetProvider.swift,
AwarenessWidget.entitlements, AwarenessWidget/Info.plist, Awareness/Info.plist
Modified: SettingsManager.swift, ContentView.swift, AwarenessApp.swift, Awareness.entitlements,
project.pbxproj (iOS), project.pbxproj (macOS), Info.plist (macOS), Awareness.csproj, CHANGELOG.md, CLAUDE.md
