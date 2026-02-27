import SwiftUI
import UserNotifications

/// Main entry point for the iOS Awareness app.
/// Handles notification delegation, foreground refresh, and blackout presentation.
@main
struct AwarenessApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, perform: { phase in
                    if phase == .active {
                        NotificationScheduler.shared.refreshOnForeground()
                    }
                })
        }
    }
}

// MARK: - App Delegate

/// Handles UNUserNotificationCenter delegation for foreground notification display
/// and notification tap responses.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Activate WatchConnectivity to sync settings with companion Apple Watch
        WatchConnectivityManager.shared.activate()

        // Request notification permission and schedule on first launch
        Task {
            let granted = await NotificationScheduler.shared.requestPermission()
            if granted {
                NotificationScheduler.shared.rescheduleAll()
            }
        }

        // Check for updates
        UpdateChecker.shared.check()

        return true
    }

    /// When a notification arrives while the app is in the foreground,
    /// show the banner so the user can actively tap to start a blackout.
    /// Also records this notification as triggered for progress tracking.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Record as triggered — the notification arrived regardless of user response
        NotificationScheduler.shared.recordNotificationTriggered(notification.request.identifier)

        completionHandler([.banner, .sound])
        NotificationScheduler.shared.refreshOnForeground()
    }

    /// When the user taps a notification or an action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        guard category == NotificationScheduler.categoryIdentifier else {
            completionHandler()
            return
        }

        // Record as triggered — covers background notifications the user tapped
        // (foreground ones were already counted in willPresent, dedup prevents double-counting)
        NotificationScheduler.shared.recordNotificationTriggered(response.notification.request.identifier)

        switch response.actionIdentifier {
        case NotificationScheduler.actionSnooze:
            // Snooze for 30 minutes without opening the app
            NotificationScheduler.shared.handleSnooze(
                until: Date().addingTimeInterval(30 * 60)
            )

        case NotificationScheduler.actionStart,
             UNNotificationDefaultActionIdentifier:
            // Tap on notification or "Start Blackout" button — show blackout
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .showBlackout, object: nil)
                NotificationScheduler.shared.refreshOnForeground()
            }

        default:
            break
        }

        completionHandler()
    }
}
