import Foundation
import UserNotifications
import Combine

/// watchOS notification scheduler — same architecture as iOS but without UIKit dependencies.
/// Pre-schedules up to 30 notifications at random intervals within the active time window.
/// No image attachment (no UIKit), uses default notification sound.
class NotificationScheduler: ObservableObject {

    static let shared = NotificationScheduler()

    /// Maximum number of pending notifications to maintain
    private static let maxPending = 30

    /// Category identifier for awareness notifications
    static let categoryIdentifier = "awareness.blackout"

    /// Identifier for the end-of-blackout signal notification.
    /// This notification is scheduled by BlackoutView when a blackout starts
    /// and fires at the exact end time. The system delivers its sound/haptic
    /// regardless of display state or main RunLoop throttling.
    static let endSignalIdentifier = "awareness-watch-blackout-end"

    /// Action identifiers for notification buttons
    static let actionStart = "awareness.action.start"
    static let actionSnooze = "awareness.action.snooze"

    private let center = UNUserNotificationCenter.current()
    private let settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    /// Notification IDs already counted as triggered this session.
    /// Prevents double-counting between willPresent, didReceive, and delivered-check.
    private var countedTriggerIDs = Set<String>()

    /// The approximate date of the next scheduled notification
    @Published private(set) var nextNotificationDate: Date?

    /// Set to true by WatchConnectivityManager while applying a remote context,
    /// so the settings observer skips spurious rescheduling.
    var isApplyingRemoteContext = false

    /// Whether the current schedule was received from the companion iPhone
    private var usingCoordinatedSchedule = false

    /// Timestamp of the last coordinated schedule received from iOS
    private var lastCoordinatedScheduleDate: Date?

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
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("Awareness Watch: notification permission request failed — \(error.localizedDescription)")
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
        // Clear existing pending and delivered notifications (IDs will be reused)
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        countedTriggerIDs.removeAll()

        guard !settings.isSnoozed else {
            nextNotificationDate = nil
            return
        }

        var lastDate = Date()
        var firstDate: Date?

        for i in 0..<NotificationScheduler.maxPending {
            let delayMinutes = randomInterval()
            let candidateDate = lastDate.addingTimeInterval(delayMinutes * 60)
            let fireDate = adjustToActiveWindow(candidateDate)

            let content = makeNotificationContent()

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "awareness-watch-\(i)",
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

    /// Apply a coordinated schedule received from the companion iPhone.
    /// Uses the exact fire dates generated by iOS to avoid overlapping notifications.
    /// Falls back to random generation if no future dates are available.
    func applyCoordinatedSchedule(_ dates: [Date]) {
        let futureDates = dates.filter { $0 > Date() }

        guard !futureDates.isEmpty else {
            // No usable future dates — fall back to independent scheduling
            usingCoordinatedSchedule = false
            rescheduleAll()
            return
        }

        center.removeAllPendingNotificationRequests()
        usingCoordinatedSchedule = true
        lastCoordinatedScheduleDate = Date()

        guard !settings.isSnoozed else {
            nextNotificationDate = nil
            return
        }

        var firstDate: Date?

        for (i, fireDate) in futureDates.enumerated() {
            let content = makeNotificationContent()

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "awareness-watch-\(i)",
                content: content,
                trigger: trigger
            )

            center.add(request)

            if firstDate == nil {
                firstDate = fireDate
            }
        }

        nextNotificationDate = firstDate
    }

    /// Top up pending notifications when the app returns to foreground.
    /// Also counts any delivered (ignored) notifications as triggered.
    func refreshOnForeground() {
        // Check if snooze has expired and auto-resume
        if let until = settings.snoozeUntil, Date() >= until {
            settings.snoozeUntil = nil
        }

        // Count any delivered notifications the user didn't respond to
        countDeliveredNotifications()

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }

            if self.settings.isSnoozed {
                self.center.removeAllPendingNotificationRequests()
                DispatchQueue.main.async {
                    self.nextNotificationDate = nil
                }
                return
            }

            let deficit = NotificationScheduler.maxPending - requests.count

            if deficit <= 0 {
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
                    identifier: "awareness-watch-\(startIndex + i)",
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

    // MARK: - Test

    /// Schedule a test notification that fires in 3 seconds
    func scheduleTestNotification() {
        let content = makeNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "awareness-watch-test",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Settings Observation

    /// Reschedule when relevant settings change (debounced).
    /// Skips rescheduling when a remote context is being applied or was recently applied —
    /// the coordinated schedule from iOS is authoritative and should not be overwritten.
    private func observeSettingsChanges() {
        settings.$minInterval
            .merge(with: settings.$maxInterval)
            .merge(with: settings.$activeStartHour.map { Double($0) })
            .merge(with: settings.$activeEndHour.map { Double($0) })
            .dropFirst(4)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isApplyingRemoteContext else { return }

                // Skip rescheduling if a coordinated schedule was applied recently —
                // the debounce fires after the flag is cleared, but the settings
                // change was from the same remote context, not a local user edit
                if self.usingCoordinatedSchedule,
                   let lastSync = self.lastCoordinatedScheduleDate,
                   Date().timeIntervalSince(lastSync) < 2.0 {
                    return
                }

                self.rescheduleAll()
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// Build notification content — no image attachment on watchOS, uses default sound
    private func makeNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Awareness reminder ☯")
        content.subtitle = String(localized: "Time to pause and breathe")
        content.body = String(localized: "Tap to begin a mindful moment.")
        content.sound = .default
        content.categoryIdentifier = NotificationScheduler.categoryIdentifier
        return content
    }

    /// Returns a random interval in minutes between the configured min and max
    private func randomInterval() -> Double {
        let minMin = settings.minInterval
        let maxMin = settings.maxInterval
        guard maxMin > minMin else { return minMin }
        return Double.random(in: minMin...maxMin)
    }

    /// Adjust a candidate fire date to fall within the active time window.
    private func adjustToActiveWindow(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let window = settings.activeTimeWindow

        if window.startHour <= window.endHour {
            if hour >= window.startHour && hour < window.endHour {
                return date
            }
            if hour >= window.endHour {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                return calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: nextDay)!
            } else {
                return calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: date)!
            }
        } else {
            if hour >= window.startHour || hour < window.endHour {
                return date
            }
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

    // MARK: - Trigger Tracking

    /// Record a specific notification as triggered, guarded against double-counting.
    /// Called from willPresent (foreground delivery) and didReceive (user tap).
    func recordNotificationTriggered(_ identifier: String) {
        if countedTriggerIDs.insert(identifier).inserted {
            ProgressTracker.shared.recordTriggered()
        }
    }

    /// Count any delivered awareness notifications as triggered and clear them.
    /// Catches notifications the user ignored (never tapped) — they sit in the
    /// notification center until the app returns to foreground.
    func countDeliveredNotifications() {
        center.getDeliveredNotifications { [weak self] notifications in
            guard let self = self else { return }
            let awareness = notifications.filter {
                $0.request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier
            }
            for n in awareness {
                self.recordNotificationTriggered(n.request.identifier)
            }
            if !awareness.isEmpty {
                let ids = awareness.map { $0.request.identifier }
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }
}
