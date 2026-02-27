import AppKit
import IOKit
import IOKit.pwr_mgt
import SwiftUI

/// Creates and manages full-screen blackout overlay windows — one per connected display.
/// The overlay sits at screenSaver window level so it covers everything.
/// During a blackout, a global event tap suppresses keyboard input to background apps.
class BlackoutWindowController {

    private var windows: [NSWindow] = []
    private var dismissTimer: DispatchWorkItem?
    private var keyEventMonitor: Any?
    private var mouseEventMonitor: Any?
    private var globalEventTap: CFMachPort?
    private var globalRunLoopSource: CFRunLoopSource?
    private var completionHandler: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    /// Power assertion ID to prevent screen saver / display sleep during blackout
    private var idleAssertionID: IOPMAssertionID = 0

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

    /// Cover all screens with the blackout overlay for a given duration
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

        // Install event monitors — local keyboard/mouse for ESC/click dismiss, global tap to suppress typing
        installKeyboardMonitor()
        installMouseClickMonitor()
        installGlobalEventTap()

        // Record that a blackout was triggered
        ProgressTracker.shared.recordTriggered()

        // Schedule automatic dismissal after the configured duration
        let work = DispatchWorkItem { [weak self] in
            ProgressTracker.shared.recordCompleted()
            self?.dismiss()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Fade out and close all overlay windows, optionally playing the end gong.
    /// Pass `silent: true` when dismissing due to system idle (sleep/lock/screensaver)
    /// to avoid playing sounds while the user isn't at the screen.
    func dismiss(silent: Bool = false) {
        dismissTimer?.cancel()
        dismissTimer = nil
        removeKeyboardMonitor()
        removeMouseClickMonitor()
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

            // In handcuffs mode, swallow key events — user cannot escape
            if SettingsManager.shared.handcuffsMode {
                return nil
            }

            // ESC or Cmd+Q dismisses the blackout early
            let isEscape = event.keyCode == 53
            let isCmdQ = event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q"

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

    // MARK: - Global Event Tap (suppress keystrokes to background apps)

    /// Install a CGEvent tap that eats keyboard events system-wide during blackout.
    /// ESC is allowed through when handcuffs mode is off so the local monitor can dismiss.
    /// Requires Accessibility permission — if not granted, the tap simply won't be created
    /// and keystrokes will pass through as before (graceful degradation).
    private func installGlobalEventTap() {
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

    private func makeOverlayWindow(
        for screen: NSScreen,
        visualType: BlackoutVisualType,
        customText: String,
        imagePath: String = "",
        videoPath: String = ""
    ) -> NSWindow {
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

        // Host the SwiftUI content view
        let contentView = BlackoutContentView(
            visualType: visualType,
            customText: customText,
            imagePath: imagePath,
            videoPath: videoPath
        )
        window.contentView = NSHostingView(rootView: contentView)

        return window
    }
}

// MARK: - BlackoutWindow subclass

/// Custom NSWindow subclass that can become key window to capture keyboard focus.
/// This pulls keyboard focus away from whatever app was active before the blackout.
class BlackoutWindow: NSWindow {

    var acceptsKeyInput = false

    override var canBecomeKey: Bool {
        return acceptsKeyInput
    }
}
