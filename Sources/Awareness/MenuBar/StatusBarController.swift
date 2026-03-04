import AppKit
import ServiceManagement

/// Manages the NSStatusItem (menu bar icon) and its dropdown menu
class StatusBarController: NSObject {

    private let statusItem: NSStatusItem
    private let blackoutController: BlackoutWindowController
    private let scheduler: BlackoutScheduler
    private let settingsWindowController = SettingsWindowController()
    private let progressWindowController = ProgressWindowController()
    private var tooltipTimer: Timer?
    private var snoozeCheckTimer: Timer?

    /// Snooze durations offered in the menu (minutes). 0 = "Until I resume"
    private static let snoozeDurations = [10, 20, 30, 60, 120, 0]

    init(blackoutController: BlackoutWindowController, scheduler: BlackoutScheduler) {
        self.blackoutController = blackoutController
        self.scheduler = scheduler
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        buildMenu()
        startTooltipUpdates()
        startSnoozeCheck()

        // Update tooltip whenever the scheduler picks a new next-blackout time
        scheduler.onNextDateChanged = { [weak self] _ in
            self?.updateTooltip()
        }
    }

    // MARK: - Menu Bar Button

    private func configureButton() {
        guard let button = statusItem.button else { return }

        if #available(macOS 14.0, *),
           let image = NSImage(systemSymbolName: "yinyang", accessibilityDescription: "Awareness") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "☯"
        }

        button.toolTip = "Awareness reminder"
    }

    // MARK: - Tooltip

    private func startTooltipUpdates() {
        tooltipTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateTooltip()
        }
    }

    private func updateTooltip() {
        guard let button = statusItem.button else { return }
        let settings = SettingsManager.shared

        if settings.isSnoozed {
            if let until = settings.snoozeUntil {
                button.toolTip = String(localized: "Awareness reminder — Snoozed until \(formatTime(until))")
            } else {
                button.toolTip = String(localized: "Awareness reminder — Snoozed indefinitely")
            }
            return
        }

        guard let nextDate = scheduler.nextBlackoutDate else {
            button.toolTip = "Awareness reminder"
            return
        }

        button.toolTip = String(localized: "Awareness reminder — Next in \(formatRemainingTime(until: nextDate))")
    }

    private func formatRemainingTime(until date: Date) -> String {
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "now" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Snooze Timer

    /// Periodically check if snooze has expired and auto-resume
    private func startSnoozeCheck() {
        snoozeCheckTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let settings = SettingsManager.shared

            // If there's a finite snooze that has expired, resume
            if let until = settings.snoozeUntil, Date() >= until {
                self.resumeFromSnooze()
            }
        }
    }

    // MARK: - Menu Construction

    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let settings = SettingsManager.shared

        // Status line at the top
        let statusText: String
        if settings.isSnoozed {
            if let until = settings.snoozeUntil {
                statusText = String(localized: "Snoozed until \(formatTime(until))")
            } else {
                statusText = String(localized: "Snoozed indefinitely")
            }
        } else if let nextDate = scheduler.nextBlackoutDate {
            statusText = String(localized: "Next break in \(formatRemainingTime(until: nextDate))")
        } else {
            statusText = String(localized: "Scheduling...")
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Progress
        let progressItem = NSMenuItem(title: String(localized: "Mindful Moments..."), action: #selector(showProgress), keyEquivalent: "p")
        progressItem.target = self
        menu.addItem(progressItem)

        menu.addItem(NSMenuItem.separator())

        // Snooze / Resume
        if settings.isSnoozed || !scheduler.isCurrentlyRunning {
            let resumeItem = NSMenuItem(title: String(localized: "Resume"), action: #selector(resumeAction), keyEquivalent: "r")
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else {
            let snoozeMenu = NSMenu()
            for minutes in StatusBarController.snoozeDurations {
                let title: String
                if minutes == 0 {
                    title = String(localized: "Until I resume")
                } else if minutes >= 60 {
                    let hours = minutes / 60
                    title = hours >= 2
                        ? String(localized: "\(hours) hours")
                        : String(localized: "\(hours) hour")
                } else {
                    title = String(localized: "\(minutes) minutes")
                }
                let item = NSMenuItem(title: title, action: #selector(snoozeSelected(_:)), keyEquivalent: "")
                item.target = self
                item.tag = minutes
                snoozeMenu.addItem(item)
            }

            let snoozeItem = NSMenuItem(title: String(localized: "Snooze"), action: nil, keyEquivalent: "")
            snoozeItem.submenu = snoozeMenu
            menu.addItem(snoozeItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Breathe now — manual blackout trigger
        let testItem = NSMenuItem(title: String(localized: "Breathe now"), action: #selector(testBlackout), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)

        // Launch at Login
        let launchAtLogin = NSMenuItem(title: String(localized: "Launch at Login"), action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLogin)

        // Settings
        let settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Help
        let helpItem = NSMenuItem(title: String(localized: "How to Use..."), action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
        menu.addItem(helpItem)

        // About
        let aboutItem = NSMenuItem(title: String(localized: "About Awareness reminder..."), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Update Available (shown only when a newer release exists on GitHub)
        if UpdateChecker.shared.updateAvailable, let version = UpdateChecker.shared.latestVersion {
            let updateItem = NSMenuItem(
                title: String(localized: "Update Available (v\(version))"),
                action: #selector(openReleasePage),
                keyEquivalent: ""
            )
            updateItem.target = self
            menu.addItem(updateItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: String(localized: "Quit Awareness reminder"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - Launch at Login

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                print("Awareness: failed to toggle launch at login — \(error.localizedDescription)")
            }
        }
        buildMenu()
    }

    // MARK: - Snooze Actions

    @objc private func snoozeSelected(_ sender: NSMenuItem) {
        let minutes = sender.tag
        if minutes == 0 {
            // Snooze indefinitely — use a far-future date
            SettingsManager.shared.snoozeUntil = Date.distantFuture
        } else {
            SettingsManager.shared.snoozeUntil = Date().addingTimeInterval(Double(minutes) * 60)
        }
        scheduler.stop()
        buildMenu()
        updateTooltip()
    }

    @objc private func resumeAction() {
        resumeFromSnooze()
    }

    private func resumeFromSnooze() {
        SettingsManager.shared.snoozeUntil = nil
        scheduler.start()
        buildMenu()
        updateTooltip()
    }

    // MARK: - Actions

    @objc private func testBlackout() {
        let settings = SettingsManager.shared
        blackoutController.show(
            duration: settings.randomBlackoutDuration(),
            visualType: settings.visualType,
            customText: settings.customText,
            imagePath: settings.customImagePath,
            videoPath: settings.customVideoPath
        )
    }

    @objc private func showProgress() {
        progressWindowController.showProgress()
    }

    @objc private func openSettings() {
        settingsWindowController.showSettings()
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = String(localized: "How to Use Awareness reminder")
        alert.informativeText = String(localized: "Awareness reminder runs quietly in your menu bar (☯ icon).\n\nHow it works:\n• At random intervals, your screen fades to black for a few seconds\n• A gong sounds at the start and end of each break\n• Use this pause to breathe, close your eyes, and reset\n\nControls:\n• ESC or Cmd+Q — dismiss a break early (unless Handcuffs mode is on)\n• Snooze — temporarily pause from the menu bar\n• Settings — configure timing, visuals, and sounds\n\nThe app detects active camera/microphone usage and will skip breaks during video calls.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "Awareness reminder"
        alert.informativeText = String(localized: "A mindfulness timer for your Mac.\nRandomly pauses your screen to help you breathe.\n\nThe goal of this app is to not need it anymore a little bit later.\n\nby joergsflow\nVersion \(version)\n\ngithub.com/joergs-git/awareness")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "View on GitHub"))
        alert.icon = NSImage(named: NSImage.applicationIconName)

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/joergs-git/awareness") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func openReleasePage() {
        if let url = URL(string: UpdateChecker.shared.releaseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }
}
