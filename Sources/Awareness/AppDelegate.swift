import AppKit
import ApplicationServices

/// Central app delegate — owns the status bar controller and coordinates app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    let blackoutController = BlackoutWindowController()
    var scheduler: BlackoutScheduler?

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scheduler = BlackoutScheduler(blackoutController: blackoutController)
        self.scheduler = scheduler

        statusBarController = StatusBarController(
            blackoutController: blackoutController,
            scheduler: scheduler
        )

        // Auto-start the scheduler
        scheduler.start()

        // Pause blackouts when the system is idle (sleep, lock screen, screensaver)
        configureSystemStateDetector()

        // Check for updates on GitHub (background, non-blocking)
        UpdateChecker.shared.check()

        // Flush any pending sync events from previous sessions
        SyncManager.shared.flushPending()

        // Pull remote events from other platforms into local progress stats
        SyncManager.shared.pullAndIntegrate()

        // Deferred startup: welcome dialog first, then permission check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showWelcomeIfFirstLaunch()
            self?.checkPermissions()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
    }

    // MARK: - System State Detection

    /// Wire up idle/active callbacks so blackouts don't fire while the user is away
    private func configureSystemStateDetector() {
        let detector = SystemStateDetector.shared

        // When the system goes idle, silently dismiss any active blackout
        detector.onSystemDidBecomeIdle = { [weak self] in
            guard let self = self else { return }
            if self.blackoutController.isActive {
                self.blackoutController.dismiss(silent: true)
            }
        }

        // When the user comes back, auto-clear any snooze and restart scheduling.
        // Without this, returning from sleep/lock while snoozed would leave the
        // scheduler stopped until the user manually clicks "Resume".
        detector.onSystemDidBecomeActive = { [weak self] in
            guard let self = self else { return }
            let settings = SettingsManager.shared

            if settings.isSnoozed || !(self.scheduler?.isCurrentlyRunning ?? false) {
                // Clear snooze and restart the scheduler
                settings.snoozeUntil = nil
                self.scheduler?.start()
                self.statusBarController?.buildMenu()
            } else {
                // Already running — just reschedule with a fresh random delay
                self.scheduler?.rescheduleIfRunning()
            }

            // Pull remote events on wake
            SyncManager.shared.pullAndIntegrate()
        }
    }

    // MARK: - First Launch Welcome

    private func showWelcomeIfFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppDelegate.hasLaunchedBeforeKey) else { return }
        defaults.set(true, forKey: AppDelegate.hasLaunchedBeforeKey)

        let alert = NSAlert()
        alert.messageText = String(localized: "Welcome to Awareness")
        alert.informativeText = String(localized: "Awareness is now running in your menu bar.\n\nLook for the ☯ icon in the top-right of your screen. Click it to access settings, snooze, or quit.\n\nYour screen will randomly fade to black at gentle intervals — a moment to pause, breathe, and return to the present.\n\nYou can configure everything from the menu bar icon → Settings.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Got it"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Permission Check

    /// Checks required system permissions on every launch.
    /// Accessibility is needed for keyboard suppression during breaks (direct distribution only).
    private func checkPermissions() {
        // Skip in sandbox — CGEvent tap is disabled there, so Accessibility is not needed
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil { return }

        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = String(localized: "Accessibility Permission Needed")
            alert.informativeText = String(localized: "Atempause needs Accessibility permission to suppress keyboard input during breathing breaks.\n\nWithout it, keystrokes may reach background apps while the screen is dimmed.\n\nGo to System Settings → Privacy & Security → Accessibility and add Atempause.")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "Open System Settings"))
            alert.addButton(withTitle: String(localized: "Later"))
            NSApp.activate(ignoringOtherApps: true)

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
