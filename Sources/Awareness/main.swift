import AppKit

// Bootstrap the application with our custom delegate
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
