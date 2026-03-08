#!/usr/bin/env swift
//
// generate-macos.swift
// Generates macOS App Store screenshots for Awareness reminder.
//
// Usage: swift generate-macos.swift
// Output: macos/ directory with blackout + progress screenshots in EN and DE
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

// Chinese sunrise palette
let donutColor = NSColor(red: 0.72, green: 0.50, blue: 0.38, alpha: 1.0)
let warmBgTop = NSColor(red: 0.98, green: 0.92, blue: 0.84, alpha: 1.0)
let warmBgBottom = NSColor(red: 0.93, green: 0.85, blue: 0.78, alpha: 1.0)

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
    weekdays: ["M", "T", "W", "T", "F", "S", "S"]
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
    weekdays: ["M", "D", "M", "D", "F", "S", "S"]
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
        // Primary arc — starts at top (-π/2), goes clockwise
        let startAngle = CGFloat.pi / 2  // In CG coords (flipped), π/2 is top
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

func generateProgress(strings: Strings) {
    let rep = createBitmapContext()
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let g = nsCtx.cgContext

    // Warm background gradient (full screen)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [warmBgTop.cgColor, warmBgBottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
    g.drawLinearGradient(gradient,
        start: CGPoint(x: width / 2, y: height),
        end: CGPoint(x: width / 2, y: 0),
        options: [])

    // Large centered progress panel — fills most of the screen
    let panelWidth: CGFloat = 1400
    let panelHeight: CGFloat = 1300
    let panelX = (width - panelWidth) / 2
    let panelY = (height - panelHeight) / 2

    // Panel background — subtle rounded rectangle
    let panelRect = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
    let panelPath = CGPath(roundedRect: panelRect, cornerWidth: 36, cornerHeight: 36, transform: nil)
    g.addPath(panelPath)
    g.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
    g.fillPath()

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

// MARK: - Main

// Ensure output directory exists
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("Generating macOS App Store screenshots (2560×1600)...")
print()

generateBlackout(strings: english)
generateBlackout(strings: german)
generateProgress(strings: english)
generateProgress(strings: german)

print()
print("Done! Screenshots saved to: \(outputDir.path)")
