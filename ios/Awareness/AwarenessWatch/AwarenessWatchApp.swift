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
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        NotificationScheduler.shared.refreshOnForeground()
                    }
                }
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
    /// Also records this notification as triggered for progress tracking
    /// and plays a reminder haptic to nudge the user.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // End-of-blackout signal — the system delivers sound/haptic at the scheduled time
        // even when the display is dimmed. Post dismiss to end the blackout visually.
        if notification.request.identifier == NotificationScheduler.endSignalIdentifier {
            completionHandler([.sound])
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dismissBlackout, object: nil)
            }
            return
        }

        // Record as triggered — the notification arrived regardless of user response
        NotificationScheduler.shared.recordNotificationTriggered(notification.request.identifier)

        // Reminder haptic — a firm nudge to pay attention
        if SettingsManager.shared.reminderHapticEnabled {
            HapticPlayer.playReminder()
        }

        completionHandler([.banner, .sound])
        NotificationScheduler.shared.refreshOnForeground()
    }

    /// When the user taps a notification or an action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // End-of-blackout signal — user tapped the notification to dismiss
        if response.notification.request.identifier == NotificationScheduler.endSignalIdentifier {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dismissBlackout, object: nil)
            }
            completionHandler()
            return
        }

        let category = response.notification.request.content.categoryIdentifier
        guard category == NotificationScheduler.categoryIdentifier else {
            completionHandler()
            return
        }

        // Record as triggered — covers background notifications the user tapped
        // (foreground ones were already counted in willPresent, dedup prevents double-counting)
        NotificationScheduler.shared.recordNotificationTriggered(response.notification.request.identifier)

        // Reminder haptic — a firm nudge when the user taps a notification
        if SettingsManager.shared.reminderHapticEnabled {
            HapticPlayer.playReminder()
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
