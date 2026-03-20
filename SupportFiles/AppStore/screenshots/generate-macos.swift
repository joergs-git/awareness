#!/usr/bin/env swift
//
// generate-macos.swift
// Generates macOS App Store screenshots for Awareness reminder.
//
// Usage: swift generate-macos.swift
// Output: macos/ directory with blackout, progress, settings, and menu bar screenshots in EN and DE
//
// Screenshot size: 2560 x 1600 (standard Mac App Store, 16" Retina)
//

import AppKit
import Foundation

// MARK: - Configuration

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("macos")
let width: CGFloat = 2560
let height: CGFloat = 1600

// Purple palette
let donutColor = NSColor(red: 0.55, green: 0.38, blue: 0.72, alpha: 1.0)
let warmBgTop = NSColor(red: 0.94, green: 0.91, blue: 0.98, alpha: 1.0)
let warmBgBottom = NSColor(red: 0.88, green: 0.84, blue: 0.94, alpha: 1.0)

// Localized strings
struct Strings {
    let breathePhrase: String
    let today: String
    let overall: String
    let lifetime: String
    let discipline: String
    let triggered: String
    let completed: String
    let suffix: String // filename suffix

    // Weekday labels
    let weekdays: [String] // M T W T F S S

    // Settings strings
    let settingsTitle: String
    let activeHours: String
    let from: String
    let until: String
    let breakDuration: String
    let intervalBetweenBreaks: String
    let visualMode: String
    let startGong: String
    let endGong: String
    let handcuffsMode: String
    let startclickConfirmation: String
    let launchAtLogin: String

    // Menu bar strings
    let breatheNow: String
    let snooze: String
    let progress: String
    let settings: String
    let aboutAwareness: String
    let quit: String
}

let english = Strings(
    breathePhrase: "Breathe.",
    today: "Today",
    overall: "Overall",
    lifetime: "Lifetime",
    discipline: "Discipline",
    triggered: "triggered",
    completed: "completed",
    suffix: "en",
    weekdays: ["M", "T", "W", "T", "F", "S", "S"],
    settingsTitle: "Awareness Settings",
    activeHours: "Active Hours",
    from: "From",
    until: "Until",
    breakDuration: "Break Duration",
    intervalBetweenBreaks: "Interval Between Breaks",
    visualMode: "Visual Mode",
    startGong: "Start Gong",
    endGong: "End Gong",
    handcuffsMode: "Handcuffs Mode",
    startclickConfirmation: "Startclick Confirmation",
    launchAtLogin: "Launch at Login",
    breatheNow: "Breathe Now",
    snooze: "Snooze",
    progress: "Progress",
    settings: "Settings...",
    aboutAwareness: "About Awareness",
    quit: "Quit"
)

let german = Strings(
    breathePhrase: "Atme.",
    today: "Heute",
    overall: "Gesamt",
    lifetime: "Gesamt",
    discipline: "Disziplin",
    triggered: "ausgelöst",
    completed: "abgeschlossen",
    suffix: "de",
    weekdays: ["M", "D", "M", "D", "F", "S", "S"],
    settingsTitle: "Awareness Einstellungen",
    activeHours: "Aktive Stunden",
    from: "Von",
    until: "Bis",
    breakDuration: "Atempausen-Dauer",
    intervalBetweenBreaks: "Intervall zwischen Pausen",
    visualMode: "Visueller Modus",
    startGong: "Start-Gong",
    endGong: "End-Gong",
    handcuffsMode: "Handschellen-Modus",
    startclickConfirmation: "Startklick-Best\u{00E4}tigung",
    launchAtLogin: "Beim Anmelden starten",
    breatheNow: "Jetzt atmen",
    snooze: "Schlummern",
    progress: "Fortschritt",
    settings: "Einstellungen \u{2026}",
    aboutAwareness: "\u{00DC}ber Awareness",
    quit: "Beenden"
)

// MARK: - Simulated Data

struct DayData {
    let weekdayIndex: Int // 0=Mon, 6=Sun
    let triggered: Int
    let completed: Int
    let isToday: Bool
}

/// Generate realistic-looking 14-day data with natural variation
func generateSimulatedDays() -> [DayData] {
    // Today is Sunday (index 6 in ISO weekday), go back 13 days
    let calendar = Calendar(identifier: .gregorian)
    let today = Date()

    var days: [DayData] = []
    for i in (0..<14).reversed() {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon, ...
        let isoIndex = (weekday + 5) % 7 // Convert to 0=Mon, 6=Sun

        // Weekdays get more breaks than weekends (more computer time)
        let isWeekend = isoIndex >= 5
        let baseTrigger = isWeekend ? Int.random(in: 2...5) : Int.random(in: 4...9)
        let completionRate = Double.random(in: 0.65...0.95)
        let completed = max(1, Int(Double(baseTrigger) * completionRate))

        days.append(DayData(
            weekdayIndex: isoIndex,
            triggered: baseTrigger,
            completed: min(completed, baseTrigger),
            isToday: i == 0
        ))
    }
    return days
}

let simulatedDays = generateSimulatedDays()

// Computed stats from simulated data
let todayData = simulatedDays.last!
let lifetimeTriggered = simulatedDays.map(\.triggered).reduce(0, +) + 142 // some historical data
let lifetimeCompleted = simulatedDays.map(\.completed).reduce(0, +) + 121

// MARK: - Drawing Helpers

func createBitmapContext() -> NSBitmapImageRep {
    return NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width),
        pixelsHigh: Int(height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
}

func saveImage(_ rep: NSBitmapImageRep, name: String) {
    let url = outputDir.appendingPathComponent(name)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: Failed to create PNG for \(name)")
        return
    }
    do {
        try data.write(to: url)
        print("Saved: \(url.lastPathComponent)")
    } catch {
        print("ERROR: \(error)")
    }
}

/// Draw the warm gradient background used by progress, settings, and menu bar screenshots
func drawWarmBackground(in context: CGContext) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [warmBgTop.cgColor, warmBgBottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(gradient,
        start: CGPoint(x: width / 2, y: height),
        end: CGPoint(x: width / 2, y: 0),
        options: [])
}

/// Draw a rounded rectangle panel with semi-transparent white fill
func drawPanel(in context: CGContext, rect: CGRect, cornerRadius: CGFloat = 36, alpha: CGFloat = 0.35) {
    let panelPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(panelPath)
    context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
    context.fillPath()
}

func drawCenteredText(_ text: String, in context: CGContext, center: CGPoint, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let nsText = text as NSString
    let size = nsText.size(withAttributes: attrs)
    let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = ctx
    nsText.draw(in: rect, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
}

func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]
    let nsText = text as NSString
    let size = nsText.size(withAttributes: attrs)

    var rect: CGRect
    if alignment == .right {
        rect = CGRect(x: point.x - size.width, y: point.y, width: size.width, height: size.height)
    } else if alignment == .center {
        rect = CGRect(x: point.x - size.width / 2, y: point.y, width: size.width, height: size.height)
    } else {
        rect = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
    }
    nsText.draw(in: rect, withAttributes: attrs)
}

/// Draw a horizontal divider line
func drawDivider(in context: CGContext, y: CGFloat, leftX: CGFloat, rightX: CGFloat) {
    context.setStrokeColor(NSColor.separatorColor.cgColor)
    context.setLineWidth(1)
    context.move(to: CGPoint(x: leftX, y: y))
    context.addLine(to: CGPoint(x: rightX, y: y))
    context.strokePath()
}

// MARK: - Blackout Screenshot

func generateBlackout(strings: Strings) {
    let rep = createBitmapContext()
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    let g = ctx.cgContext

    // Full black background
    g.setFillColor(NSColor.black.cgColor)
    g.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Breathing text — centered, 72pt (doubled for retina), light weight, semi-transparent white
    let font = NSFont.systemFont(ofSize: 72, weight: .light)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.7),
        .paragraphStyle: paragraphStyle
    ]

    let text = strings.breathePhrase as NSString
    let textSize = text.size(withAttributes: attrs)
    let textRect = CGRect(
        x: (width - textSize.width) / 2,
        y: (height - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    saveImage(rep, name: "blackout-\(strings.suffix).png")
}

// MARK: - Progress Screenshot

func drawDonut(in context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, rate: Double) {
    // Background ring
    context.setStrokeColor(NSColor.gray.withAlphaComponent(0.15).cgColor)
    context.setLineWidth(lineWidth)
    context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    context.strokePath()

    if rate > 0 {
        // Primary arc — starts at top (-pi/2), goes clockwise
        let startAngle = CGFloat.pi / 2  // In CG coords (flipped), pi/2 is top
        let endAngle = startAngle - CGFloat(rate) * .pi * 2

        context.setStrokeColor(donutColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.strokePath()

        // Brush overlay 1 — slightly offset, semi-transparent
        context.setStrokeColor(donutColor.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(lineWidth * 0.85)
        context.addArc(
            center: CGPoint(x: center.x + 2, y: center.y + 1.6),
            radius: radius,
            startAngle: startAngle, endAngle: endAngle, clockwise: true
        )
        context.strokePath()

        // Brush overlay 2
        context.setStrokeColor(donutColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(lineWidth * 0.6)
        context.addArc(
            center: CGPoint(x: center.x - 1.6, y: center.y - 2.4),
            radius: radius,
            startAngle: startAngle, endAngle: endAngle, clockwise: true
        )
        context.strokePath()
    }
}

func generateProgress(strings: Strings) {
    let rep = createBitmapContext()
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let g = nsCtx.cgContext

    // Warm background gradient (full screen)
    drawWarmBackground(in: g)

    // Large centered progress panel — fills most of the screen
    let panelWidth: CGFloat = 1400
    let panelHeight: CGFloat = 1300
    let panelX = (width - panelWidth) / 2
    let panelY = (height - panelHeight) / 2

    // Panel background — subtle rounded rectangle
    let panelRect = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
    drawPanel(in: g, rect: panelRect)

    let panelPad: CGFloat = 60

    // --- Donut Charts ---
    let donutRadius: CGFloat = 160
    let donutLineWidth: CGFloat = 50
    let donutY = panelY + panelHeight - 280

    let todayRate = Double(todayData.completed) / Double(max(todayData.triggered, 1))
    let overallRate = Double(lifetimeCompleted) / Double(max(lifetimeTriggered, 1))

    // Today donut (left)
    let leftDonutCenter = CGPoint(x: panelX + panelWidth * 0.3, y: donutY)
    drawDonut(in: g, center: leftDonutCenter, radius: donutRadius, lineWidth: donutLineWidth, rate: todayRate)

    // Center text for today donut
    drawCenteredText("\(Int(todayRate * 100))%",
        in: g, center: CGPoint(x: leftDonutCenter.x, y: leftDonutCenter.y + 8),
        font: .systemFont(ofSize: 60, weight: .bold), color: .labelColor)
    drawCenteredText(strings.discipline,
        in: g, center: CGPoint(x: leftDonutCenter.x, y: leftDonutCenter.y - 38),
        font: .systemFont(ofSize: 24), color: .secondaryLabelColor)

    // "Today" label below left donut
    drawText(strings.today,
        at: CGPoint(x: leftDonutCenter.x, y: donutY - donutRadius - 50),
        font: .systemFont(ofSize: 30), color: .secondaryLabelColor, alignment: .center)

    // Overall donut (right)
    let rightDonutCenter = CGPoint(x: panelX + panelWidth * 0.7, y: donutY)
    drawDonut(in: g, center: rightDonutCenter, radius: donutRadius, lineWidth: donutLineWidth, rate: overallRate)

    drawCenteredText("\(Int(overallRate * 100))%",
        in: g, center: CGPoint(x: rightDonutCenter.x, y: rightDonutCenter.y + 8),
        font: .systemFont(ofSize: 60, weight: .bold), color: .labelColor)
    drawCenteredText(strings.discipline,
        in: g, center: CGPoint(x: rightDonutCenter.x, y: rightDonutCenter.y - 38),
        font: .systemFont(ofSize: 24), color: .secondaryLabelColor)

    // "Overall" label below right donut
    drawText(strings.overall,
        at: CGPoint(x: rightDonutCenter.x, y: donutY - donutRadius - 50),
        font: .systemFont(ofSize: 30), color: .secondaryLabelColor, alignment: .center)

    // --- Stats ---
    let statsY = donutY - donutRadius - 120
    let statsLeftX = panelX + panelPad
    let statsRightX = panelX + panelWidth - panelPad

    // Today stats
    drawText(strings.today, at: CGPoint(x: statsLeftX, y: statsY),
        font: .systemFont(ofSize: 36, weight: .medium), color: .labelColor)
    drawText("\(todayData.completed) \(strings.completed), \(todayData.triggered) \(strings.triggered)",
        at: CGPoint(x: statsRightX, y: statsY),
        font: .systemFont(ofSize: 36), color: .secondaryLabelColor, alignment: .right)

    // Lifetime stats
    let lifetimeY = statsY - 56
    drawText(strings.lifetime, at: CGPoint(x: statsLeftX, y: lifetimeY),
        font: .systemFont(ofSize: 36, weight: .medium), color: .labelColor)
    drawText("\(lifetimeCompleted) \(strings.completed), \(lifetimeTriggered) \(strings.triggered)",
        at: CGPoint(x: statsRightX, y: lifetimeY),
        font: .systemFont(ofSize: 36), color: .secondaryLabelColor, alignment: .right)

    // Divider
    let dividerY = lifetimeY - 36
    g.setStrokeColor(NSColor.separatorColor.cgColor)
    g.setLineWidth(2)
    g.move(to: CGPoint(x: panelX + panelPad, y: dividerY))
    g.addLine(to: CGPoint(x: panelX + panelWidth - panelPad, y: dividerY))
    g.strokePath()

    // --- 14-Day Bar Chart ---
    let chartTop = dividerY - 30
    let chartHeight: CGFloat = 240
    let chartBottom = chartTop - chartHeight
    let chartLeftX = panelX + panelPad
    let chartWidth = panelWidth - panelPad * 2
    let barGroupWidth = chartWidth / 14
    let barWidth: CGFloat = 22
    let barGap: CGFloat = 4

    let maxVal = simulatedDays.map { max($0.triggered, $0.completed) }.max() ?? 1

    for (i, day) in simulatedDays.enumerated() {
        let groupCenterX = chartLeftX + barGroupWidth * (CGFloat(i) + 0.5)

        // Triggered bar (gray)
        if day.triggered > 0 {
            let h = max(CGFloat(day.triggered) / CGFloat(maxVal) * chartHeight, 6)
            let barRect = CGRect(
                x: groupCenterX - barWidth - barGap / 2,
                y: chartBottom,
                width: barWidth,
                height: h
            )
            let barPath = CGPath(roundedRect: barRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
            g.addPath(barPath)
            g.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            g.fillPath()
        }

        // Completed bar (earthy)
        if day.completed > 0 {
            let h = max(CGFloat(day.completed) / CGFloat(maxVal) * chartHeight, 6)
            let barRect = CGRect(
                x: groupCenterX + barGap / 2,
                y: chartBottom,
                width: barWidth,
                height: h
            )
            let barPath = CGPath(roundedRect: barRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
            g.addPath(barPath)
            g.setFillColor(donutColor.cgColor)
            g.fillPath()
        }

        // Weekday label
        let wdIndex = day.weekdayIndex
        let label = strings.weekdays[wdIndex]
        let labelColor: NSColor = day.isToday ? .labelColor : .secondaryLabelColor
        let labelFont: NSFont = day.isToday ? .systemFont(ofSize: 24, weight: .bold) : .systemFont(ofSize: 24)
        drawText(label, at: CGPoint(x: groupCenterX, y: chartBottom - 36),
            font: labelFont, color: labelColor, alignment: .center)
    }

    // Legend
    let legendY = chartBottom - 80
    let legendCenterX = panelX + panelWidth / 2

    // Triggered legend box
    let triggeredBoxRect = CGRect(x: legendCenterX - 200, y: legendY, width: 22, height: 22)
    g.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
    g.fill(triggeredBoxRect)
    drawText(strings.triggered, at: CGPoint(x: legendCenterX - 170, y: legendY - 2),
        font: .systemFont(ofSize: 26), color: .secondaryLabelColor)

    // Completed legend box
    let completedBoxRect = CGRect(x: legendCenterX + 40, y: legendY, width: 22, height: 22)
    g.setFillColor(donutColor.cgColor)
    g.fill(completedBoxRect)
    drawText(strings.completed, at: CGPoint(x: legendCenterX + 70, y: legendY - 2),
        font: .systemFont(ofSize: 26), color: .secondaryLabelColor)

    NSGraphicsContext.restoreGraphicsState()
    saveImage(rep, name: "progress-\(strings.suffix).png")
}

// MARK: - Settings Screenshot

/// Draw a macOS-style window title bar with traffic light buttons
func drawWindowTitleBar(in context: CGContext, rect: CGRect, title: String, cornerRadius: CGFloat = 16) {
    let titleBarHeight: CGFloat = 52

    // Window shadow
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 30,
        color: NSColor.black.withAlphaComponent(0.25).cgColor)

    // Window body (full rounded rect, white)
    let windowPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(windowPath)
    context.setFillColor(NSColor(white: 0.98, alpha: 1.0).cgColor)
    context.fillPath()

    // Reset shadow
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // Title bar background — slightly darker strip at top
    let titleBarRect = CGRect(x: rect.minX, y: rect.maxY - titleBarHeight, width: rect.width, height: titleBarHeight)

    // Clip to window shape so top corners stay rounded
    context.saveGState()
    context.addPath(windowPath)
    context.clip()
    context.setFillColor(NSColor(white: 0.94, alpha: 1.0).cgColor)
    context.fill(titleBarRect)

    // Title bar bottom separator
    context.setStrokeColor(NSColor(white: 0.85, alpha: 1.0).cgColor)
    context.setLineWidth(1)
    context.move(to: CGPoint(x: rect.minX, y: rect.maxY - titleBarHeight))
    context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - titleBarHeight))
    context.strokePath()
    context.restoreGState()

    // Traffic lights (close, minimize, zoom)
    let trafficY = rect.maxY - titleBarHeight / 2
    let trafficStartX = rect.minX + 24
    let trafficSpacing: CGFloat = 22
    let trafficRadius: CGFloat = 8

    let trafficColors: [NSColor] = [
        NSColor(red: 1.0, green: 0.38, blue: 0.34, alpha: 1.0), // red
        NSColor(red: 1.0, green: 0.74, blue: 0.21, alpha: 1.0), // yellow
        NSColor(red: 0.15, green: 0.78, blue: 0.24, alpha: 1.0)  // green
    ]
    for (i, color) in trafficColors.enumerated() {
        let cx = trafficStartX + CGFloat(i) * trafficSpacing
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: cx - trafficRadius, y: trafficY - trafficRadius,
            width: trafficRadius * 2, height: trafficRadius * 2))
    }

    // Title text — centered in the title bar
    drawText(title,
        at: CGPoint(x: rect.midX, y: rect.maxY - titleBarHeight / 2 - 12),
        font: .systemFont(ofSize: 24, weight: .semibold), color: .labelColor, alignment: .center)
}

/// Draw a toggle switch (pill shape) in on or off state
func drawToggle(in context: CGContext, at point: CGPoint, isOn: Bool) {
    let toggleWidth: CGFloat = 60
    let toggleHeight: CGFloat = 30
    let toggleRect = CGRect(x: point.x - toggleWidth, y: point.y - 2, width: toggleWidth, height: toggleHeight)
    let togglePath = CGPath(roundedRect: toggleRect, cornerWidth: toggleHeight / 2, cornerHeight: toggleHeight / 2, transform: nil)

    // Track color
    let trackColor: NSColor = isOn ? donutColor : NSColor(white: 0.82, alpha: 1.0)
    context.addPath(togglePath)
    context.setFillColor(trackColor.cgColor)
    context.fillPath()

    // Thumb circle
    let thumbRadius: CGFloat = 12
    let thumbX = isOn ? toggleRect.maxX - thumbRadius - 4 : toggleRect.minX + thumbRadius + 4
    let thumbY = toggleRect.midY
    context.setFillColor(NSColor.white.cgColor)
    context.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.2).cgColor)
    context.fillEllipse(in: CGRect(x: thumbX - thumbRadius, y: thumbY - thumbRadius,
        width: thumbRadius * 2, height: thumbRadius * 2))
    context.setShadow(offset: .zero, blur: 0, color: nil)
}

/// Draw a settings row with a toggle switch on the right
func drawSettingsToggleRow(in context: CGContext, label: String, isOn: Bool, y: CGFloat, leftX: CGFloat, rightX: CGFloat) {
    drawText(label, at: CGPoint(x: leftX, y: y), font: .systemFont(ofSize: 26), color: .labelColor)
    drawToggle(in: context, at: CGPoint(x: rightX, y: y), isOn: isOn)
}

/// Draw a range slider with two thumbs and value labels below
func drawRangeSlider(in context: CGContext, y: CGFloat, leftX: CGFloat, rightX: CGFloat,
                     minRatio: CGFloat, maxRatio: CGFloat, minLabel: String, maxLabel: String) {
    let sliderWidth = rightX - leftX
    let sliderY = y + 14

    // Track background
    context.setFillColor(NSColor(white: 0.85, alpha: 1.0).cgColor)
    let trackRect = CGRect(x: leftX, y: sliderY - 3, width: sliderWidth, height: 6)
    let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
    context.addPath(trackPath)
    context.fillPath()

    // Active range highlight
    let minPos = leftX + sliderWidth * minRatio
    let maxPos = leftX + sliderWidth * maxRatio
    context.setFillColor(donutColor.cgColor)
    let activeTrack = CGRect(x: minPos, y: sliderY - 3, width: maxPos - minPos, height: 6)
    context.fill(activeTrack)

    // Thumb circles at min and max positions
    let thumbR: CGFloat = 12
    for pos in [minPos, maxPos] {
        context.setFillColor(NSColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.fillEllipse(in: CGRect(x: pos - thumbR, y: sliderY - thumbR, width: thumbR * 2, height: thumbR * 2))
        context.setShadow(offset: .zero, blur: 0, color: nil)
    }

    // Value labels below the thumbs
    let labelY = y - 18
    drawText(minLabel, at: CGPoint(x: minPos, y: labelY), font: .systemFont(ofSize: 22), color: .secondaryLabelColor, alignment: .center)
    drawText(maxLabel, at: CGPoint(x: maxPos, y: labelY), font: .systemFont(ofSize: 22), color: .secondaryLabelColor, alignment: .center)
}

func generateSettings(strings: Strings) {
    let rep = createBitmapContext()
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let g = nsCtx.cgContext

    // Warm background gradient
    drawWarmBackground(in: g)

    // Settings window dimensions
    let winWidth: CGFloat = 900
    let winHeight: CGFloat = 1200
    let winX = (width - winWidth) / 2
    let winY = (height - winHeight) / 2
    let winRect = CGRect(x: winX, y: winY, width: winWidth, height: winHeight)

    // Draw window with title bar
    drawWindowTitleBar(in: g, rect: winRect, title: strings.settingsTitle)

    // Content area layout constants
    let contentPad: CGFloat = 50
    let leftX = winX + contentPad
    let rightX = winX + winWidth - contentPad
    let rowHeight: CGFloat = 56
    let sectionGap: CGFloat = 28

    // Start below title bar with top padding
    var y = winY + winHeight - 52 - 50

    // --- Active Hours Section ---
    drawText(strings.activeHours, at: CGPoint(x: leftX, y: y),
        font: .systemFont(ofSize: 28, weight: .semibold), color: .labelColor)
    y -= rowHeight

    // From / Until on one row
    drawText(strings.from, at: CGPoint(x: leftX + 20, y: y), font: .systemFont(ofSize: 26), color: .labelColor)
    drawText("06:00", at: CGPoint(x: leftX + 260, y: y), font: .systemFont(ofSize: 26), color: .secondaryLabelColor, alignment: .right)
    drawText(strings.until, at: CGPoint(x: leftX + 400, y: y), font: .systemFont(ofSize: 26), color: .labelColor)
    drawText("22:00", at: CGPoint(x: rightX, y: y), font: .systemFont(ofSize: 26), color: .secondaryLabelColor, alignment: .right)

    y -= sectionGap
    drawDivider(in: g, y: y, leftX: leftX, rightX: rightX)
    y -= sectionGap

    // --- Break Duration ---
    drawText(strings.breakDuration, at: CGPoint(x: leftX, y: y),
        font: .systemFont(ofSize: 28, weight: .semibold), color: .labelColor)
    y -= rowHeight

    // Range slider: 20-40s within a 5-120s range (ratios ~0.13 and ~0.30)
    drawRangeSlider(in: g, y: y, leftX: leftX + 20, rightX: rightX,
                    minRatio: 0.13, maxRatio: 0.30, minLabel: "20s", maxLabel: "40s")

    y -= sectionGap + 26
    drawDivider(in: g, y: y, leftX: leftX, rightX: rightX)
    y -= sectionGap

    // --- Interval Between Breaks ---
    drawText(strings.intervalBetweenBreaks, at: CGPoint(x: leftX, y: y),
        font: .systemFont(ofSize: 28, weight: .semibold), color: .labelColor)
    y -= rowHeight

    // Range slider: 15-30 min within a 5-120 min range (ratios ~0.087 and ~0.217)
    drawRangeSlider(in: g, y: y, leftX: leftX + 20, rightX: rightX,
                    minRatio: 0.087, maxRatio: 0.217, minLabel: "15 min", maxLabel: "30 min")

    y -= sectionGap + 26
    drawDivider(in: g, y: y, leftX: leftX, rightX: rightX)
    y -= sectionGap

    // --- Visual Mode ---
    drawText(strings.visualMode, at: CGPoint(x: leftX, y: y),
        font: .systemFont(ofSize: 28, weight: .semibold), color: .labelColor)
    drawText("Rotating Text", at: CGPoint(x: rightX, y: y),
        font: .systemFont(ofSize: 26), color: .secondaryLabelColor, alignment: .right)

    y -= sectionGap
    drawDivider(in: g, y: y, leftX: leftX, rightX: rightX)
    y -= sectionGap

    // --- Toggle Settings ---
    drawSettingsToggleRow(in: g, label: strings.startGong, isOn: true, y: y, leftX: leftX, rightX: rightX)
    y -= rowHeight

    drawSettingsToggleRow(in: g, label: strings.endGong, isOn: true, y: y, leftX: leftX, rightX: rightX)
    y -= rowHeight

    drawSettingsToggleRow(in: g, label: strings.handcuffsMode, isOn: false, y: y, leftX: leftX, rightX: rightX)
    y -= rowHeight

    drawSettingsToggleRow(in: g, label: strings.startclickConfirmation, isOn: true, y: y, leftX: leftX, rightX: rightX)
    y -= rowHeight

    drawSettingsToggleRow(in: g, label: strings.launchAtLogin, isOn: true, y: y, leftX: leftX, rightX: rightX)

    NSGraphicsContext.restoreGraphicsState()
    saveImage(rep, name: "settings-\(strings.suffix).png")
}

// MARK: - Menu Bar Screenshot

/// Draw a macOS menu bar strip at the top of the screen with system items and yin-yang icon.
/// Returns the X position of the yin-yang icon for dropdown alignment.
func drawMenuBar(in context: CGContext) -> CGFloat {
    let menuBarHeight: CGFloat = 50

    // Semi-transparent light bar
    context.setFillColor(NSColor(white: 0.98, alpha: 0.92).cgColor)
    context.fill(CGRect(x: 0, y: height - menuBarHeight, width: width, height: menuBarHeight))

    // Bottom edge line
    context.setStrokeColor(NSColor(white: 0.82, alpha: 1.0).cgColor)
    context.setLineWidth(1)
    context.move(to: CGPoint(x: 0, y: height - menuBarHeight))
    context.addLine(to: CGPoint(x: width, y: height - menuBarHeight))
    context.strokePath()

    // Apple menu (left side)
    drawText("\u{F8FF}", at: CGPoint(x: 22, y: height - menuBarHeight + 10),
        font: .systemFont(ofSize: 28, weight: .regular), color: .labelColor)

    // Left-side menu items (Finder style)
    let leftItems = ["Finder", "File", "Edit", "View", "Go", "Window", "Help"]
    var itemX: CGFloat = 60
    for item in leftItems {
        drawText(item, at: CGPoint(x: itemX, y: height - menuBarHeight + 10),
            font: .systemFont(ofSize: 24, weight: item == "Finder" ? .bold : .regular), color: .labelColor)
        let itemWidth = (item as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 24)]).width
        itemX += itemWidth + 28
    }

    // Right-side system tray: clock, Wi-Fi, battery percentage
    let rightItems = ["100%", "Wi-Fi", "10:42"]
    var rightX: CGFloat = width - 30
    for item in rightItems.reversed() {
        let itemWidth = (item as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 22)]).width
        rightX -= itemWidth
        drawText(item, at: CGPoint(x: rightX, y: height - menuBarHeight + 12),
            font: .systemFont(ofSize: 22), color: .labelColor)
        rightX -= 24
    }

    // Yin-yang icon (the Awareness status item) — positioned in the tray area
    let yinyangX = rightX - 10
    drawText("\u{262F}", at: CGPoint(x: yinyangX, y: height - menuBarHeight + 8),
        font: .systemFont(ofSize: 28), color: .labelColor)

    return yinyangX
}

func generateMenuBar(strings: Strings) {
    let rep = createBitmapContext()
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let g = nsCtx.cgContext

    // Warm gradient desktop wallpaper
    drawWarmBackground(in: g)

    // Draw the menu bar and get the yin-yang icon position
    let yinyangX = drawMenuBar(in: g)

    // Dropdown menu — positioned below the yin-yang icon
    let menuBarHeight: CGFloat = 50
    let menuWidth: CGFloat = 340
    let menuItemHeight: CGFloat = 44
    let separatorHeight: CGFloat = 16

    // Menu items: nil represents a separator line
    let menuItems: [String?] = [
        strings.breatheNow,
        strings.snooze + " \u{25B8}",  // right-pointing triangle for submenu indicator
        nil,
        strings.progress,
        strings.settings,
        nil,
        strings.aboutAwareness,
        strings.quit
    ]

    // Calculate total menu height including padding
    var menuHeight: CGFloat = 16 // top + bottom padding (8 each)
    for item in menuItems {
        menuHeight += item == nil ? separatorHeight : menuItemHeight
    }

    // Center the dropdown horizontally under the yin-yang icon
    let menuX = yinyangX - menuWidth / 2 + 14
    let menuY = height - menuBarHeight - menuHeight - 6
    let menuRect = CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)

    // Menu shadow
    g.setShadow(offset: CGSize(width: 0, height: -6), blur: 24,
        color: NSColor.black.withAlphaComponent(0.22).cgColor)

    // Menu background
    let menuPath = CGPath(roundedRect: menuRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    g.addPath(menuPath)
    g.setFillColor(NSColor(white: 0.99, alpha: 0.98).cgColor)
    g.fillPath()

    // Reset shadow
    g.setShadow(offset: .zero, blur: 0, color: nil)

    // Menu border
    g.addPath(menuPath)
    g.setStrokeColor(NSColor(white: 0.82, alpha: 1.0).cgColor)
    g.setLineWidth(0.5)
    g.strokePath()

    // Draw each menu item top-to-bottom
    var itemY = menuY + menuHeight - 8
    let itemLeftPad: CGFloat = 20

    for (index, item) in menuItems.enumerated() {
        if let label = item {
            // Subtle highlight on the first item ("Breathe Now")
            if index == 0 {
                let highlightRect = CGRect(x: menuX + 6, y: itemY - menuItemHeight + 4,
                    width: menuWidth - 12, height: menuItemHeight - 2)
                let highlightPath = CGPath(roundedRect: highlightRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
                g.addPath(highlightPath)
                g.setFillColor(donutColor.withAlphaComponent(0.12).cgColor)
                g.fillPath()
            }

            let textY = itemY - menuItemHeight + 10
            drawText(label, at: CGPoint(x: menuX + itemLeftPad, y: textY),
                font: .systemFont(ofSize: 26), color: .labelColor)

            itemY -= menuItemHeight
        } else {
            // Separator line
            let sepY = itemY - separatorHeight / 2
            g.setStrokeColor(NSColor.separatorColor.cgColor)
            g.setLineWidth(1)
            g.move(to: CGPoint(x: menuX + 10, y: sepY))
            g.addLine(to: CGPoint(x: menuX + menuWidth - 10, y: sepY))
            g.strokePath()

            itemY -= separatorHeight
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    saveImage(rep, name: "menubar-\(strings.suffix).png")
}

// MARK: - Main

// Ensure output directory exists
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("Generating macOS App Store screenshots (2560\u{00D7}1600)...")
print()

generateBlackout(strings: english)
generateBlackout(strings: german)
generateProgress(strings: english)
generateProgress(strings: german)
generateSettings(strings: english)
generateSettings(strings: german)
generateMenuBar(strings: english)
generateMenuBar(strings: german)

print()
print("Done! Screenshots saved to: \(outputDir.path)")
