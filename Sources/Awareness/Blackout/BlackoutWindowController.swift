import AppKit
import IOKit
import IOKit.pwr_mgt
import StoreKit
import SwiftUI

/// Creates and manages full-screen blackout overlay windows — one per connected display.
/// The overlay sits at screenSaver window level so it covers everything.
///
/// **Input suppression:** A CGEvent tap suppresses global keystrokes (ESC passes through
/// when handcuffs mode is off). Requires Accessibility permission — degrades gracefully
/// if not granted. `NSApp.activate(ignoringOtherApps:)` ensures overlay captures focus.
///
/// **Click-to-dismiss:** Local key/mouse monitors handle clicks when overlay has focus;
/// a global mouse monitor provides fallback when another app steals focus.
class BlackoutWindowController {

    private var windows: [NSWindow] = []
    private var dismissTimer: DispatchWorkItem?
    private var keyEventMonitor: Any?
    private var mouseEventMonitor: Any?
    private var globalMouseMonitor: Any?
    private var globalEventTap: CFMachPort?
    private var globalRunLoopSource: CFRunLoopSource?
    private var completionHandler: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    /// Power assertion ID to prevent screen saver / display sleep during blackout
    private var idleAssertionID: IOPMAssertionID = 0

    /// State for post-blackout namaste → card+task flow
    private var phaseState: BlackoutPhaseState?
    /// Whether the blackout is in a post-breathing phase (namaste or card)
    private var isInPostBlackoutPhase = false

    // MARK: - Sync Event Tracking
    /// Tracks the current blackout event lifecycle for Supabase upload
    /// Stored as pre-formatted ISO 8601 string to guarantee upsert match between START and END uploads
    private var syncEventStartTimeISO: String?
    private var syncEventDuration: TimeInterval = 0
    private var syncEventCompleted = false
    private var syncEventAwareness: String?

    /// Tracks when the actual breathing phase started, for recording elapsed duration
    private var breathingStartDate: Date?

    // MARK: - Startclick Confirmation State

    /// Whether we're currently showing the "Ready to breathe?" confirmation screen
    private var isInConfirmationPhase = false
    /// Stored blackout config for after the user confirms
    private var pendingDuration: TimeInterval = 0
    private var pendingVisualType: BlackoutVisualType = .plainBlack
    private var pendingCustomText: String = ""
    private var pendingImagePath: String = ""
    private var pendingVideoPath: String = ""

    /// Fade animation duration in seconds
    private let fadeDuration: TimeInterval = 2.0

    /// Whether a blackout is currently being displayed
    var isActive: Bool { !windows.isEmpty }

    init() {
        // Watch for screen configuration changes (plugging/unplugging displays)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Show / Dismiss

    /// Cover all screens with the blackout overlay for a given duration.
    /// When "Startclick confirmation" is enabled, shows a "Ready to breathe?" prompt first.
    func show(
        duration: TimeInterval,
        visualType: BlackoutVisualType = .plainBlack,
        customText: String = "",
        imagePath: String = "",
        videoPath: String = "",
        completion: (() -> Void)? = nil
    ) {
        guard !isActive else { return }
        self.completionHandler = completion

        // If startclick confirmation is enabled, show the prompt first
        if SettingsManager.shared.startclickConfirmation {
            pendingDuration = duration
            pendingVisualType = visualType
            pendingCustomText = customText
            pendingImagePath = imagePath
            pendingVideoPath = videoPath
            showConfirmation()
        } else {
            // Direct blackout — original behavior
            showBlackout(
                duration: duration,
                visualType: visualType,
                customText: customText,
                imagePath: imagePath,
                videoPath: videoPath
            )
        }
    }

    // MARK: - Startclick Confirmation

    /// Show the "Ready to breathe?" confirmation screen on all displays
    private func showConfirmation() {
        isInConfirmationPhase = true

        // Track sync event start time now so both confirm and decline can upload
        syncEventStartTimeISO = SupabaseClient.formatDate(Date())
        syncEventDuration = pendingDuration
        syncEventCompleted = false
        syncEventAwareness = nil

        // Upload initial event so other platforms see a break is happening
        uploadSyncEvent()

        // Record that a blackout was triggered (whether user accepts or declines)
        ProgressTracker.shared.recordTriggered()

        // Create confirmation overlay windows on all screens
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen, contentView: AnyView(
                BlackoutConfirmationView(
                    onConfirm: { [weak self] in self?.handleConfirmYes() },
                    onDecline: { [weak self] in self?.handleConfirmNo() }
                )
            ))
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windows {
                window.animator().alphaValue = 1
            }
        }

        // Only install keyboard monitor for ESC handling — no global tap, no mouse suppression,
        // no IOPMAssertion (allow display sleep to naturally dismiss the confirmation)
        installKeyboardMonitor()
    }

    /// User confirmed — transition from confirmation to actual blackout
    private func handleConfirmYes() {
        isInConfirmationPhase = false

        // Track sync event from confirmation start — format once, reuse for upsert match
        syncEventStartTimeISO = SupabaseClient.formatDate(Date())
        syncEventDuration = pendingDuration
        syncEventCompleted = false
        syncEventAwareness = nil

        // Track breathing start for duration measurement
        breathingStartDate = Date()

        // Upload immediately so iOS knows a desktop break just started
        uploadSyncEvent()

        // Replace window content with the actual blackout view
        let contentView = BlackoutContentView(
            visualType: pendingVisualType,
            customText: pendingCustomText,
            imagePath: pendingImagePath,
            videoPath: pendingVideoPath
        )
        for window in windows {
            window.contentView = NSHostingView(rootView: contentView)
        }

        // Now play start gong
        GongPlayer.shared.playStartIfEnabled()

        // Prevent display sleep during the breathing session
        let assertionResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awareness blackout in progress" as CFString,
            &idleAssertionID
        )
        if assertionResult != kIOReturnSuccess {
            print("Awareness: failed to create idle display sleep assertion")
        }

        // Remove the lightweight keyboard monitor and install the full set
        removeKeyboardMonitor()
        installKeyboardMonitor()
        installMouseClickMonitor()
        installGlobalMouseMonitor()
        installGlobalEventTap()

        // Schedule transition to post-blackout phase after breathing completes
        let work = DispatchWorkItem { [weak self] in
            ProgressTracker.shared.recordCompleted()
            // Record actual elapsed duration for the trend chart
            if let start = self?.breathingStartDate {
                ProgressTracker.shared.recordSessionDuration(Date().timeIntervalSince(start))
            }
            self?.syncEventCompleted = true
            // Prompt for App Store review at milestone completions (sandbox/App Store builds only)
            if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil,
               ProgressTracker.shared.shouldRequestReview() {
                SKStoreReviewController.requestReview()
            }
            self?.beginPostBlackoutPhase()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingDuration, execute: work)
    }

    /// User declined — dismiss silently without counting as completed
    private func handleConfirmNo() {
        isInConfirmationPhase = false
        // Upload sync event for the declined confirmation (triggered but not completed)
        uploadSyncEvent()
        dismiss(silent: true)
    }

    // MARK: - Direct Blackout (original flow)

    /// Show the blackout immediately without confirmation
    private func showBlackout(
        duration: TimeInterval,
        visualType: BlackoutVisualType,
        customText: String,
        imagePath: String,
        videoPath: String
    ) {
        // Track sync event for Supabase upload — format once, reuse for upsert match
        syncEventStartTimeISO = SupabaseClient.formatDate(Date())
        syncEventDuration = duration
        syncEventCompleted = false
        syncEventAwareness = nil

        // Track breathing start for duration measurement
        breathingStartDate = Date()

        // Upload immediately so iOS knows a desktop break just started
        uploadSyncEvent()

        // Play start gong immediately (before fade begins)
        GongPlayer.shared.playStartIfEnabled()

        // Create one overlay window per connected screen, starting fully transparent
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(
                for: screen,
                visualType: visualType,
                customText: customText,
                imagePath: imagePath,
                videoPath: videoPath
            )
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }

        // Force this application to the foreground so keyboard and mouse events
        // are delivered to our overlay windows instead of the previously active app
        NSApp.activate(ignoringOtherApps: true)

        // Make the first overlay window key so it captures keyboard input
        windows.first?.makeKeyAndOrderFront(nil)

        // Fade in over 2 seconds
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windows {
                window.animator().alphaValue = 1
            }
        }

        // Prevent screen saver and display sleep during the blackout
        let assertionResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awareness blackout in progress" as CFString,
            &idleAssertionID
        )
        if assertionResult != kIOReturnSuccess {
            print("Awareness: failed to create idle display sleep assertion")
        }

        // Install event monitors — local keyboard/mouse for ESC/click dismiss,
        // global tap to suppress typing, global mouse monitor as backup for dismissal
        installKeyboardMonitor()
        installMouseClickMonitor()
        installGlobalMouseMonitor()
        installGlobalEventTap()

        // Record that a blackout was triggered
        ProgressTracker.shared.recordTriggered()

        // Schedule transition to post-blackout phase after breathing completes
        let work = DispatchWorkItem { [weak self] in
            ProgressTracker.shared.recordCompleted()
            // Record actual elapsed duration for the trend chart
            if let start = self?.breathingStartDate {
                ProgressTracker.shared.recordSessionDuration(Date().timeIntervalSince(start))
            }
            self?.syncEventCompleted = true
            // Prompt for App Store review at milestone completions (sandbox/App Store builds only)
            if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil,
               ProgressTracker.shared.shouldRequestReview() {
                SKStoreReviewController.requestReview()
            }
            self?.beginPostBlackoutPhase()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: - Post-Blackout Phase (Awareness Check → Card + Micro-Task)

    /// After breathing completes, transition to awareness check → card+task flow.
    /// Play end gong, swap window content to PostBlackoutView, show awareness check.
    private func beginPostBlackoutPhase() {
        isInPostBlackoutPhase = true

        // Play end gong at the breathing → awareness check transition
        GongPlayer.shared.playEndIfEnabled()

        // Get today's card and a fresh random micro-task
        let card = SettingsManager.shared.todaysPracticeCard()
        let task = SettingsManager.shared.randomMicroTask()

        // Create shared phase state
        let state = BlackoutPhaseState()
        state.practiceCard = card
        state.microTask = task
        state.onAwarenessAnswered = { [weak self] in
            guard let self = self, self.isActive, self.isInPostBlackoutPhase else { return }
            // Capture awareness score for sync upload
            if let score = state.awarenessScore {
                self.syncEventAwareness = "\(score)"
            }
            state.phase = .practiceCard
        }
        state.onDismissRequest = { [weak self] in
            // Upload sync event before dismissing (full lifecycle complete)
            self?.uploadSyncEvent()
            self?.dismiss(silent: true)  // silent: end gong already played
        }
        self.phaseState = state

        // Swap all window contents to PostBlackoutView
        let postView = PostBlackoutView(state: state)
        for window in windows {
            window.contentView = NSHostingView(rootView: postView)
        }

        // Remove breathing-phase monitors and reinstall for post-blackout
        removeKeyboardMonitor()
        removeMouseClickMonitor()
        removeGlobalMouseMonitor()
        installPostBlackoutKeyboardMonitor()
        installPostBlackoutMouseMonitor()
        // Keep global event tap active to prevent background typing

        // Show the awareness check — user interaction drives the transition to card
        state.phase = .awarenessCheck
    }

    /// Keyboard monitor during post-blackout: any key dismisses card phase (no handcuffs check)
    private func installPostBlackoutKeyboardMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isActive, self.isInPostBlackoutPhase else { return event }

            // During awareness check, let SwiftUI buttons handle interaction
            if self.phaseState?.phase == .awarenessCheck {
                return nil
            }

            // During card phase, any key dismisses
            self.dismiss(silent: true)
            return nil
        }
    }

    /// Mouse monitor during post-blackout: click anywhere dismisses card phase (no handcuffs check)
    private func installPostBlackoutMouseMonitor() {
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.isActive, self.isInPostBlackoutPhase else { return event }

            // During awareness check, let SwiftUI buttons handle the click
            if self.phaseState?.phase == .awarenessCheck {
                return event
            }

            // During card phase, click anywhere dismisses
            self.dismiss(silent: true)
            return nil
        }
    }

    /// Fade out and close all overlay windows, optionally playing the end gong.
    /// Pass `silent: true` when dismissing due to system idle (sleep/lock/screensaver)
    /// to avoid playing sounds while the user isn't at the screen.
    func dismiss(silent: Bool = false) {
        // Record elapsed duration for early dismissals (not post-blackout phase,
        // because completed sessions already recorded duration in the timer callback)
        if !isInPostBlackoutPhase, let start = breathingStartDate {
            ProgressTracker.shared.recordSessionDuration(Date().timeIntervalSince(start))
        }
        breathingStartDate = nil

        // Upload sync event if not already uploaded (early dismiss, system idle, etc.)
        uploadSyncEvent()

        dismissTimer?.cancel()
        dismissTimer = nil
        isInPostBlackoutPhase = false
        phaseState = nil
        removeKeyboardMonitor()
        removeMouseClickMonitor()
        removeGlobalMouseMonitor()
        removeGlobalEventTap()

        // Release the display sleep prevention assertion
        if idleAssertionID != 0 {
            IOPMAssertionRelease(idleAssertionID)
            idleAssertionID = 0
        }

        // Play deeper end gong unless this is a silent dismiss (system went idle)
        if !silent {
            GongPlayer.shared.playEndIfEnabled()
        }

        let windowsToClose = windows
        windows.removeAll()

        // Fade out over 2 seconds, then close
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windowsToClose {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            for window in windowsToClose {
                window.orderOut(nil)
            }
            let handler = self?.completionHandler
            self?.completionHandler = nil
            handler?()
        })
    }

    // MARK: - Sync Upload

    /// Upload the current blackout event to Supabase via upsert.
    /// Called at blackout START (completed=false) and again at END (completed=true, awareness set).
    /// The upsert (merge-duplicates) updates the row with the final data on the second call.
    /// Uses recordEventRaw with the pre-formatted ISO string to guarantee upsert key match.
    private func uploadSyncEvent() {
        guard let startTimeISO = syncEventStartTimeISO else { return }

        SyncManager.shared.recordEventRaw(
            startedAt: startTimeISO,
            duration: syncEventDuration,
            completed: syncEventCompleted,
            awareness: syncEventAwareness
        )
    }

    // MARK: - Screen Change Handling

    /// When displays are connected/disconnected during a blackout, adjust overlays to match
    private func handleScreenChange() {
        guard isActive else { return }

        // Remove windows for screens that no longer exist
        let currentFrames = Set(NSScreen.screens.map { NSStringFromRect($0.frame) })
        windows.removeAll { window in
            let frameStr = NSStringFromRect(window.frame)
            if !currentFrames.contains(frameStr) {
                window.orderOut(nil)
                return true
            }
            return false
        }

        // Add windows for any new screens
        let existingFrames = Set(windows.map { NSStringFromRect($0.frame) })
        for screen in NSScreen.screens {
            let frameStr = NSStringFromRect(screen.frame)
            if !existingFrames.contains(frameStr) {
                let window = makeOverlayWindow(for: screen, visualType: .plainBlack, customText: "")
                window.orderFrontRegardless()
                windows.append(window)
            }
        }
    }

    // MARK: - Local Keyboard Monitor (for ESC / Cmd+Q dismissal)

    private func installKeyboardMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isActive else { return event }

            let isEscape = event.keyCode == 53
            let isCmdQ = event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q"

            // During confirmation phase: ESC always counts as "No" — declining the
            // invitation is not "escaping", so handcuffs mode doesn't apply here
            if self.isInConfirmationPhase {
                if isEscape || isCmdQ {
                    self.handleConfirmNo()
                    return nil
                }
                return nil  // swallow other keys
            }

            // During breathing phase: handcuffs mode prevents early dismissal
            if SettingsManager.shared.handcuffsMode {
                return nil
            }

            // ESC or Cmd+Q dismisses the blackout early
            if isEscape || isCmdQ {
                self.dismiss()
                return nil
            }

            return nil  // swallow all other keys during blackout
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    // MARK: - Local Mouse Click Monitor (for click-to-dismiss)

    private func installMouseClickMonitor() {
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.isActive else { return event }

            // In handcuffs mode, swallow mouse clicks — user cannot escape
            if SettingsManager.shared.handcuffsMode {
                return nil
            }

            // Click anywhere on the overlay to dismiss
            self.dismiss()
            return nil
        }
    }

    private func removeMouseClickMonitor() {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }

    // MARK: - Global Mouse Monitor (backup dismiss when app loses focus)

    /// Global monitor catches mouse clicks even when another app has focus.
    /// This handles the case where focus is stolen by a notification or other app
    /// during the blackout — the local monitor wouldn't fire, but this one will.
    /// Note: global monitors can observe but not suppress events.
    private func installGlobalMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self = self, self.isActive else { return }

            // During post-blackout: only dismiss during card phase (not awareness check)
            if self.isInPostBlackoutPhase {
                if self.phaseState?.phase == .practiceCard {
                    NSApp.activate(ignoringOtherApps: true)
                    self.dismiss(silent: true)
                }
                return
            }

            guard !SettingsManager.shared.handcuffsMode else { return }

            // Re-activate our app and dismiss — the click already went to the other app,
            // but at least we dismiss the blackout so the user isn't stuck
            NSApp.activate(ignoringOtherApps: true)
            self.dismiss()
        }
    }

    private func removeGlobalMouseMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    // MARK: - Global Event Tap (suppress keystrokes to background apps)

    /// Install a CGEvent tap that eats keyboard events system-wide during blackout.
    /// ESC is allowed through when handcuffs mode is off so the local monitor can dismiss.
    /// Requires Accessibility permission — if not granted, the tap simply won't be created
    /// and keystrokes will pass through as before (graceful degradation).
    private func installGlobalEventTap() {
        // CGEvent tap requires Accessibility permission, which Apple rejects for
        // non-accessibility purposes in sandboxed Mac App Store builds (guideline 2.4.5).
        // Skip entirely in the sandbox — the overlay windows capture focus anyway.
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, _ in
                // Let ESC (keyCode 53) pass through when handcuffs mode is off —
                // the local keyboard monitor handles dismissal for ESC
                if !SettingsManager.shared.handcuffsMode,
                   type == .keyDown || type == .keyUp {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 { // ESC
                        return Unmanaged.passUnretained(event)
                    }
                }
                // Suppress all other keyboard events to prevent typing in background apps
                return nil
            },
            userInfo: nil
        ) else {
            // Accessibility permission not granted — degrade gracefully
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        globalEventTap = tap
        globalRunLoopSource = source
    }

    private func removeGlobalEventTap() {
        if let tap = globalEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            globalEventTap = nil
        }
        if let source = globalRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            globalRunLoopSource = nil
        }
    }

    // MARK: - Window Factory

    /// Create an overlay window with the standard blackout content view
    private func makeOverlayWindow(
        for screen: NSScreen,
        visualType: BlackoutVisualType,
        customText: String,
        imagePath: String = "",
        videoPath: String = ""
    ) -> NSWindow {
        let contentView = BlackoutContentView(
            visualType: visualType,
            customText: customText,
            imagePath: imagePath,
            videoPath: videoPath
        )
        return makeOverlayWindow(for: screen, contentView: AnyView(contentView))
    }

    /// Create an overlay window with arbitrary SwiftUI content (used for confirmation view)
    private func makeOverlayWindow(for screen: NSScreen, contentView: AnyView) -> NSWindow {
        let window = BlackoutWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Window configuration for a full-screen overlay
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsKeyInput = true

        window.contentView = NSHostingView(rootView: contentView)

        return window
    }
}

// MARK: - BlackoutWindow subclass

/// Custom NSWindow subclass that can become both key and main window to fully
/// capture keyboard and mouse focus away from whatever app was active before the blackout.
class BlackoutWindow: NSWindow {

    var acceptsKeyInput = false

    override var canBecomeKey: Bool {
        return acceptsKeyInput
    }

    override var canBecomeMain: Bool {
        return acceptsKeyInput
    }
}
