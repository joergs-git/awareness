# Lessons Learned

## [2026-02-28] — watchOS DispatchSourceTimer + main.async breaks end signals
- **Mistake:** Replaced repeating `Timer.scheduledTimer` (main RunLoop) with one-shot `DispatchSourceTimer` (background queue) that dispatched to `DispatchQueue.main.async` for dismiss. This made end haptics WORSE — they didn't fire until user physically tapped the app icon.
- **Root cause:** `DispatchQueue.main.async` from a background queue does NOT execute when the main RunLoop is throttled (display dimmed on watchOS). The block just sits queued. A repeating Timer at least catches up on wrist-raise.
- **Rule:** Never replace a repeating main-thread timer with a one-shot background-to-main dispatch on watchOS. If you need background-queue reliability, fire the critical action (haptics) directly from the background queue — don't dispatch back to main.
- **Applies to:** watchOS BlackoutView timer, any watchOS background queue → main thread pattern

## [2026-02-28] — Audio keep-alive with .ambient session counterproductive on watchOS
- **Mistake:** Added a near-silent AVAudioEngine tone with `.ambient` audio session category to keep the audio engine active during blackout, hoping it would improve process scheduling priority.
- **Root cause:** `.ambient` audio sessions get deactivated when watchOS dims the display. Keeping AVAudioEngine running with a session that gets yanked makes things worse, not better.
- **Rule:** Don't use `.ambient` AVAudioEngine keep-alive for watchOS display dimming mitigation. If audio-based keep-alive is needed, it would require `.playback` category (but that ignores mute — bad for a mindfulness app).
- **Applies to:** watchOS ChimePlayer, any watchOS audio session management during display dim

## [2026-02-28] — WKInterfaceDevice.play() doesn't fire when display is dimmed
- **Mistake:** Added a background DispatchSourceTimer that called `WKInterfaceDevice.current().play(.directionUp)` directly from a background queue, expecting haptics to fire when the display is dimmed.
- **Root cause:** `WKInterfaceDevice.play()` also doesn't work when the display is dimmed — watchOS throttles all app-level APIs. Only system-level mechanisms (local notifications) can deliver haptic feedback in this state.
- **Rule:** On watchOS, the ONLY reliable way to deliver haptic/sound when the display is dimmed is via local notifications (`UNNotificationRequest`). The OS delivers notification sound/haptic at the system level, independent of app RunLoop and display state.
- **Applies to:** watchOS end-of-blackout signal, any watchOS time-critical haptic delivery

## [2026-02-28] — WKExtendedRuntimeSession blocks system-level notification delivery
- **Mistake:** Used `WKExtendedRuntimeSession` during blackouts AND scheduled a local notification for the end signal. The notification was supposed to deliver haptic at the system level, but it didn't — because the extended session kept the app in "foreground" state.
- **Root cause:** When the app is in the foreground, notifications are routed through `willPresent` (main thread). The main thread is throttled when the display dims. So the notification sound/haptic doesn't play until the delegate callback returns, which doesn't happen until wrist-raise.
- **Rule:** If you need system-level notification delivery (haptic/sound when display is dimmed), do NOT use `WKExtendedRuntimeSession`. Let watchOS suspend the app so notifications bypass the app delegate entirely.
- **Applies to:** watchOS blackout, any watchOS scenario needing reliable timed haptic/sound delivery
