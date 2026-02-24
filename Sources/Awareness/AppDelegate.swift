import AppKit

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

        // Show a welcome message on first launch
        showWelcomeIfFirstLaunch()
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

        // When the user comes back, reschedule with a fresh random delay
        detector.onSystemDidBecomeActive = { [weak self] in
            self?.scheduler?.rescheduleIfRunning()
        }
    }

    // MARK: - First Launch Welcome

    private func showWelcomeIfFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppDelegate.hasLaunchedBeforeKey) else { return }
        defaults.set(true, forKey: AppDelegate.hasLaunchedBeforeKey)

        // Small delay so the menu bar icon is visible before the alert appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Welcome to Awareness"
            alert.informativeText = """
                Awareness is now running in your menu bar.

                Look for the ☯ icon in the top-right of your screen. Click it to access settings, snooze, or quit.

                Your screen will randomly fade to black at gentle intervals — a moment to pause, breathe, and return to the present.

                You can configure everything from the menu bar icon → Settings.
                """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got it")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
