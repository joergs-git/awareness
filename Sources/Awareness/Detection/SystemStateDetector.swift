import Foundation
import AppKit

/// Detects whether the system is in an idle state (sleeping, display off, screen locked,
/// or screensaver running). Observes system notifications to track these states and
/// provides callbacks for idle/active transitions.
/// Blackouts are pointless during these states — the user isn't looking at the screen.
class SystemStateDetector {

    static let shared = SystemStateDetector()

    // MARK: - State Flags

    private(set) var isSleeping = false
    private(set) var isDisplayAsleep = false
    private(set) var isScreenLocked = false
    private(set) var isScreensaverRunning = false

    /// Returns true if ANY idle condition is active
    func isSystemIdle() -> Bool {
        return isSleeping || isDisplayAsleep || isScreenLocked || isScreensaverRunning
    }

    // MARK: - Transition Callbacks

    /// Fires on transition from active to idle (at least one flag became true)
    var onSystemDidBecomeIdle: (() -> Void)?

    /// Fires when all flags clear and the system returns to active use
    var onSystemDidBecomeActive: (() -> Void)?

    // MARK: - Init

    private init() {
        observeWorkspaceNotifications()
        observeDistributedNotifications()
    }

    // MARK: - NSWorkspace Notifications (sleep/wake, display sleep/wake)

    private func observeWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            self,
            selector: #selector(handleSystemSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDisplaySleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDisplayWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    // MARK: - Distributed Notifications (screen lock/unlock, screensaver start/stop)

    private func observeDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScreensaverStarted),
            name: NSNotification.Name("com.apple.screensaver.didStart"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScreensaverStopped),
            name: NSNotification.Name("com.apple.screensaver.didStop"),
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc private func handleSystemSleep() {
        setFlag(\.isSleeping, to: true)
    }

    @objc private func handleSystemWake() {
        setFlag(\.isSleeping, to: false)
    }

    @objc private func handleDisplaySleep() {
        setFlag(\.isDisplayAsleep, to: true)
    }

    @objc private func handleDisplayWake() {
        setFlag(\.isDisplayAsleep, to: false)
    }

    @objc private func handleScreenLocked() {
        setFlag(\.isScreenLocked, to: true)
    }

    @objc private func handleScreenUnlocked() {
        setFlag(\.isScreenLocked, to: false)
    }

    @objc private func handleScreensaverStarted() {
        setFlag(\.isScreensaverRunning, to: true)
    }

    @objc private func handleScreensaverStopped() {
        setFlag(\.isScreensaverRunning, to: false)
    }

    // MARK: - State Transition Logic

    /// Updates a flag and fires the appropriate callback on idle/active transitions
    private func setFlag(_ keyPath: ReferenceWritableKeyPath<SystemStateDetector, Bool>, to value: Bool) {
        let wasIdle = isSystemIdle()
        self[keyPath: keyPath] = value
        let isIdle = isSystemIdle()

        if !wasIdle && isIdle {
            onSystemDidBecomeIdle?()
        } else if wasIdle && !isIdle {
            onSystemDidBecomeActive?()
        }
    }
}
