import SwiftUI
import WatchKit
import UserNotifications

/// Main entry point for the watchOS Awareness app.
/// Handles notification delegation, WatchConnectivity activation,
/// and foreground refresh of scheduled notifications.
@main
struct AwarenessWatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate
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

// MARK: - Watch App Delegate

/// Handles notification delegation and app lifecycle events on watchOS.
class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self

        // Activate WatchConnectivity to sync settings with companion iPhone
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
    }

    /// When a notification arrives while the app is in the foreground,
    /// show the banner so the user can actively tap to start a blackout.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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

        switch response.actionIdentifier {
        case NotificationScheduler.actionSnooze:
            // Snooze for 30 minutes
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
