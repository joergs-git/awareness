import AppKit

/// Central app delegate — owns the status bar controller and coordinates app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    let blackoutController = BlackoutWindowController()
    var scheduler: BlackoutScheduler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scheduler = BlackoutScheduler(blackoutController: blackoutController)
        self.scheduler = scheduler

        statusBarController = StatusBarController(
            blackoutController: blackoutController,
            scheduler: scheduler
        )

        // Auto-start the scheduler
        scheduler.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
    }
}
