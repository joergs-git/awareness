# v3.03 — Practice Cards + Micro-Tasks + Twin Donuts for macOS + Micro-Task Rotation

## Task A: Copy Model Files to macOS

- [x] A.1 Copy PracticeCard.swift from iOS to Sources/Awareness/Models/
- [x] A.2 Copy MicroTask.swift from iOS to Sources/Awareness/Models/

## Task B: Extend macOS SettingsManager

- [x] B.1 Add practice card & micro-task UserDefaults keys
- [x] B.2 Add todaysPracticeCard() — daily random, avoids yesterday
- [x] B.3 Add randomMicroTask() — fresh random each call, avoids last 3
- [x] B.4 Add todayString() helper

## Task C: Post-Blackout Phase (macOS)

- [x] C.1 Create BlackoutPhaseState.swift (phase enum + observable state)
- [x] C.2 Add PostBlackoutView to BlackoutContentView.swift (namaste + card + micro-task)
- [x] C.3 Add beginPostBlackoutPhase() to BlackoutWindowController
- [x] C.4 Modify dismiss timer to transition to post-blackout instead of immediate dismiss
- [x] C.5 Add post-blackout keyboard/mouse monitors (any click/key dismisses during card phase)
- [x] C.6 Update global mouse monitor for post-blackout phase handling

## Task D: Twin Donuts (macOS ProgressView)

- [x] D.1 Replace single donut with twin donuts (Today + Overall)
- [x] D.2 Port brush-stroke effect from iOS (4-layer overlapping arcs)
- [x] D.3 Use warm earthy donut color matching iOS Chinese sunrise palette
- [x] D.4 Update bar chart to use donut color instead of green

## Task E: macOS Xcode Project (pbxproj)

- [x] E.1 Add PracticeCard.swift (B20019/A20019)
- [x] E.2 Add MicroTask.swift (B20020/A20020)
- [x] E.3 Add BlackoutPhaseState.swift (B20021/A20021)
- [x] E.4 Add to Models and Blackout groups
- [x] E.5 Add to Sources build phase

## Task F: iOS/watchOS Micro-Task Rotation

- [x] F.1 Add rotateMicroTask() to iOS SettingsManager
- [x] F.2 Call rotateMicroTask() in iOS handlePostBlackout()
- [x] F.3 Call rotateMicroTask() in watchOS post-blackout onChange

## Task G: Version Bump + Docs

- [x] G.1 SupportFiles/Info.plist → 3.03
- [x] G.2 Awareness.xcodeproj/project.pbxproj → 3.03 (2 configs)
- [x] G.3 ios/Awareness/.../project.pbxproj → 3.03 (8 configs)
- [x] G.4 windows/Awareness/Awareness.csproj → 3.03.0
- [x] G.5 CHANGELOG.md — add v3.03 entry

## Verification

- [x] H.1 macOS SPM build — BUILD SUCCEEDED
- [x] H.2 iOS build (all targets: iOS + watchOS + widget) — BUILD SUCCEEDED

## Results

All tasks completed. New files: PracticeCard.swift, MicroTask.swift, BlackoutPhaseState.swift (macOS).
Modified: SettingsManager.swift (macOS + iOS), BlackoutContentView.swift (macOS),
BlackoutWindowController.swift (macOS), ProgressView.swift (macOS),
project.pbxproj (macOS + iOS), ContentView.swift (iOS + watchOS),
Info.plist, Awareness.csproj, CHANGELOG.md.
