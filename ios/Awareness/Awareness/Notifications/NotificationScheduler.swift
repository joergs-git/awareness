import Foundation
import UIKit
import UserNotifications
import Combine

/// Replaces BlackoutScheduler for iOS — uses local notifications instead of timers.
/// Pre-schedules up to 30 notifications at random intervals within the active time window.
/// Refreshes pending notifications when the app returns to foreground.
class NotificationScheduler: ObservableObject {

    static let shared = NotificationScheduler()

    /// Maximum number of pending notifications to maintain
    private static let maxPending = 30

    /// Category identifier for awareness notifications
    static let categoryIdentifier = "awareness.blackout"

    /// Action identifiers for notification buttons
    static let actionStart = "awareness.action.start"
    static let actionSnooze = "awareness.action.snooze"

    /// Custom notification sound using the bundled gong
    private static let notificationSound = UNNotificationSound(named: UNNotificationSoundName("awareness-gong.aiff"))

    private let center = UNUserNotificationCenter.current()
    private let settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    /// The approximate date of the next scheduled notification
    @Published private(set) var nextNotificationDate: Date?

    private init() {
        registerCategory()
        observeSettingsChanges()
    }

    // MARK: - Category Registration

    /// Register notification category with action buttons
    private func registerCategory() {
        let startAction = UNNotificationAction(
            identifier: NotificationScheduler.actionStart,
            title: String(localized: "Start Blackout"),
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: NotificationScheduler.actionSnooze,
            title: String(localized: "Snooze 30 min"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationScheduler.categoryIdentifier,
            actions: [startAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Awareness: notification permission request failed — \(error.localizedDescription)")
            return false
        }
    }

    /// Check if notifications are currently authorized
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Scheduling

    /// Schedule notifications up to the maximum, starting from now.
    /// Removes all existing pending notifications and creates fresh ones.
    func rescheduleAll() {
        // Clear existing
        center.removeAllPendingNotificationRequests()

        guard !settings.isSnoozed else {
            nextNotificationDate = nil
            return
        }

        var lastDate = Date()
        var firstDate: Date?

        for i in 0..<NotificationScheduler.maxPending {
            // Pick a random delay for the next notification
            let delayMinutes = randomInterval()
            let candidateDate = lastDate.addingTimeInterval(delayMinutes * 60)

            // Adjust to respect the active time window
            let fireDate = adjustToActiveWindow(candidateDate)

            let content = makeNotificationContent()

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "awareness-\(i)",
                content: content,
                trigger: trigger
            )

            center.add(request)

            if firstDate == nil {
                firstDate = fireDate
            }
            lastDate = fireDate
        }

        nextNotificationDate = firstDate
    }

    /// Top up pending notifications when the app returns to foreground.
    /// Keeps the total count at maxPending by adding new ones after the last existing one.
    func refreshOnForeground() {
        // Check if snooze has expired and auto-resume
        if let until = settings.snoozeUntil, Date() >= until {
            settings.snoozeUntil = nil
        }

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }

            // If snoozed, clear everything
            if self.settings.isSnoozed {
                self.center.removeAllPendingNotificationRequests()
                DispatchQueue.main.async {
                    self.nextNotificationDate = nil
                }
                return
            }

            let deficit = NotificationScheduler.maxPending - requests.count

            if deficit <= 0 {
                // Update next date from earliest pending
                self.updateNextDate(from: requests)
                return
            }

            // Find the latest scheduled date among existing requests
            var latestDate = Date()
            for req in requests {
                if let trigger = req.trigger as? UNCalendarNotificationTrigger,
                   let date = trigger.nextTriggerDate(), date > latestDate {
                    latestDate = date
                }
            }

            // Add new notifications to fill the deficit
            let startIndex = requests.count
            for i in 0..<deficit {
                let delayMinutes = self.randomInterval()
                let candidateDate = latestDate.addingTimeInterval(delayMinutes * 60)
                let fireDate = self.adjustToActiveWindow(candidateDate)

                let content = self.makeNotificationContent()

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "awareness-\(startIndex + i)",
                    content: content,
                    trigger: trigger
                )

                self.center.add(request)
                latestDate = fireDate
            }

            // Re-fetch to update next date
            self.center.getPendingNotificationRequests { updated in
                self.updateNextDate(from: updated)
            }
        }
    }

    // MARK: - Snooze

    /// Remove all pending notifications when snoozing
    func handleSnooze(until date: Date?) {
        settings.snoozeUntil = date
        center.removeAllPendingNotificationRequests()
        nextNotificationDate = nil
    }

    /// Clear snooze and reschedule all notifications
    func handleResume() {
        settings.snoozeUntil = nil
        rescheduleAll()
    }

    // MARK: - Settings Observation

    /// Reschedule when relevant settings change (debounced)
    private func observeSettingsChanges() {
        settings.$minInterval
            .merge(with: settings.$maxInterval)
            .merge(with: settings.$activeStartHour.map { Double($0) })
            .merge(with: settings.$activeEndHour.map { Double($0) })
            .dropFirst(4)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.rescheduleAll()
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// Build the notification content with title, subtitle, sound, category, and image attachment
    private func makeNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Awareness ☯")
        content.subtitle = String(localized: "Time to pause and breathe")
        content.body = String(localized: "Tap to begin a mindful moment. Close your eyes, feel your breath, and return to the present.")
        content.sound = NotificationScheduler.notificationSound
        content.categoryIdentifier = NotificationScheduler.categoryIdentifier

        // Attach the app icon as a thumbnail image
        if let attachment = createIconAttachment() {
            content.attachments = [attachment]
        }

        return content
    }

    /// Create a notification attachment from the bundled app icon
    private func createIconAttachment() -> UNNotificationAttachment? {
        // Copy the logo image to a temporary file (notifications need a file URL)
        guard let image = UIImage(named: "Logo"),
              let data = image.pngData() else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("notification-icon.png")

        do {
            try data.write(to: fileURL)
            return try UNNotificationAttachment(
                identifier: "icon",
                url: fileURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
            )
        } catch {
            return nil
        }
    }

    /// Schedule a test notification that fires in 3 seconds (for preview/testing)
    func scheduleTestNotification() {
        let content = makeNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "awareness-test",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Returns a random interval in minutes between the configured min and max
    private func randomInterval() -> Double {
        let minMin = settings.minInterval
        let maxMin = settings.maxInterval
        guard maxMin > minMin else { return minMin }
        return Double.random(in: minMin...maxMin)
    }

    /// Adjust a candidate fire date to fall within the active time window.
    /// If the date is outside the window, advance it to the start of the next active period.
    private func adjustToActiveWindow(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let window = settings.activeTimeWindow

        if window.startHour <= window.endHour {
            // Normal range, e.g. 06:00-20:00
            if hour >= window.startHour && hour < window.endHour {
                return date // Already within the window
            }
            // Advance to next window start
            if hour >= window.endHour {
                // Next day's start hour
                let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                return calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: nextDay)!
            } else {
                // Before today's start hour
                return calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: date)!
            }
        } else {
            // Overnight range, e.g. 22:00-06:00
            if hour >= window.startHour || hour < window.endHour {
                return date // Already within the window
            }
            // Advance to today's start hour (the evening part)
            return calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: date)!
        }
    }

    /// Update the nextNotificationDate from an array of pending requests
    private func updateNextDate(from requests: [UNNotificationRequest]) {
        var earliest: Date?
        for req in requests {
            if let trigger = req.trigger as? UNCalendarNotificationTrigger,
               let date = trigger.nextTriggerDate() {
                if earliest == nil || date < earliest! {
                    earliest = date
                }
            }
        }
        DispatchQueue.main.async {
            self.nextNotificationDate = earliest
        }
    }
}
