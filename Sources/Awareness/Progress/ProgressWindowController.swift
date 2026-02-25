import AppKit
import SwiftUI

/// Manages a single progress window that hosts the SwiftUI ProgressView.
/// Only one progress window is shown at a time — reopening brings it to front.
class ProgressWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?

    func showProgress() {
        // If window already exists, just bring it to front
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let progressView = ProgressView()
        let hostingView = NSHostingView(rootView: progressView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Progress")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
