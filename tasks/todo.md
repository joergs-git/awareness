# Smart Guru — Implementation Todo

## Phase 1: Today Donut + Slogans + Practice Cards + Micro-Tasks

- [x] 1.1 Create `PracticeCard.swift` model (7 cards with colors, titles, descriptions, prompts)
- [x] 1.2 Create `MicroTask.swift` model (~66 tasks linked to cards)
- [x] 1.3 Create `DailySelfReport` model (in EventStore.swift)
- [x] 1.4 Redesign `ProgressView.swift` (iOS): two donuts, brush stroke, earthy color, slogans
- [x] 1.5 Redesign `ProgressView.swift` (watchOS): two donuts, earthy color, slogans
- [x] 1.6 Update `ContentView.swift` (iOS): practice card banner, micro-task card, self-report counters
- [x] 1.7 Update `ContentView.swift` (watchOS): compact status bar, self-report on card
- [x] 1.8 Update `BlackoutView.swift` (iOS): event recording, guru-adapted durations
- [x] 1.9 Add morning practice card notification to NotificationScheduler
- [x] 1.10 Create card/task full-screen views with aquarelle backgrounds

## Phase 2: Event-Level Logging

- [x] 2.1 Create `MindfulEvent.swift` model (+ AdaptiveState, GuruPhase)
- [x] 2.2 Create `EventStore.swift` singleton (90-day rolling window, hour/weekday profiles)
- [x] 2.3 Record events in BlackoutView (.completed / .dismissed)
- [x] 2.4 Record events in NotificationScheduler (.ignored)
- [x] 2.5 Integrate ForegroundScheduler with effective intervals

## Phase 3: Smart Guru Algorithm + Toggle

- [x] 3.1 Create `SmartGuru.swift` algorithm (iOS only, with duration adaptation)
- [x] 3.2 Add `smartGuruEnabled` + adaptive state to SettingsManager
- [x] 3.3 Update SettingsView: guru toggle, adaptive info display
- [x] 3.4 Integrate with NotificationScheduler + ForegroundScheduler
- [x] 3.5 Guru state synced via connectivityContext

## Cross-cutting

- [x] 4.1 Add all new files to pbxproj (iOS + watchOS + widget targets)
- [x] 4.2 Add all EN/DE translations to Localizable.xcstrings
- [ ] 4.3 Commit and push

## Additional Requests

- [x] 5.1 Duration adaptation: decrease by 5s on 3+ dismissals, increase 1s/day at 85%+ rate
- [x] 5.2 watchOS complication: progress counter (2/5) on circular yin-yang icon
- [x] 5.3 watchOS ContentView: compact status (dot + time + counter), self-report tracking
- [x] 5.4 Practice card rectangular complication (card title + micro-task)

## Results

All phases implemented. Both iOS and watchOS targets build successfully.
New files: PracticeCard.swift, MicroTask.swift, MindfulEvent.swift, EventStore.swift, SmartGuru.swift
Modified: SettingsManager, SettingsView, ContentView (iOS+watchOS), ProgressView (iOS+watchOS),
BlackoutView, ForegroundScheduler, NotificationScheduler, ComplicationProvider, Localizable.xcstrings, project.pbxproj
