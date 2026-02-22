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

        // Show a welcome message on first launch
        showWelcomeIfFirstLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
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
