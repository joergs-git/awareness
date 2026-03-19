import AppKit
import SwiftUI

/// Manages a single setup guide window that hosts the SwiftUI SetupGuideView.
/// Only one window is shown at a time — reopening brings it to front.
class SetupGuideWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?

    func showGuide() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let guideView = SetupGuideView()
        let hostingView = NSHostingView(rootView: guideView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Setup Guide")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
