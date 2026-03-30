import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI settings form for configuring all Awareness preferences
struct SettingsView: View {

    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if #available(macOS 14.0, *) {
                    Image(systemName: "yinyang")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                Text(String(localized: "Awareness Settings"))
                    .font(.title2.weight(.medium))
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            Form {
                // MARK: - Schedule
                Section {
                    // Active time window as two side-by-side pickers
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "From"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $settings.activeStartHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 90)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Until"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $settings.activeEndHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 90)
                        }

                        Spacer()
                    }
                } header: {
                    Label(String(localized: "Active Hours"), systemImage: "clock")
                }

                // MARK: - Interval Range (single compound control)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(settings.minInterval)) min")
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                                .frame(width: 55, alignment: .trailing)
                            Text("–")
                                .foregroundColor(.secondary)
                            Text("\(Int(settings.maxInterval)) min")
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                                .frame(width: 55, alignment: .leading)
                            Spacer()
                        }

                        RangeSliderView(
                            low: $settings.minInterval,
                            high: $settings.maxInterval,
                            range: 1...120,
                            step: 1
                        )
                    }
                } header: {
                    Label(String(localized: "Interval Between Breaks"), systemImage: "timer")
                }

                // MARK: - Blackout Duration
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(settings.minBlackoutDuration))s")
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                                .frame(width: 40, alignment: .trailing)
                            Text("–")
                                .foregroundColor(.secondary)
                            Text("\(Int(settings.maxBlackoutDuration))s")
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                                .frame(width: 40, alignment: .leading)
                            Spacer()
                        }

                        RangeSliderView(
                            low: $settings.minBlackoutDuration,
                            high: $settings.maxBlackoutDuration,
                            range: 3...120,
                            step: 1
                        )
                    }
                } header: {
                    Label(String(localized: "Break Duration"), systemImage: "eye.slash")
                }

                // MARK: - Visual Type
                Section {
                    Picker(String(localized: "Style"), selection: $settings.visualType) {
                        ForEach(BlackoutVisualType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch settings.visualType {
                    case .text:
                        TextField(String(localized: "Display text"), text: $settings.customText)
                            .textFieldStyle(.roundedBorder)

                    case .image:
                        FilePickerRow(
                            label: "Image",
                            path: $settings.customImagePath,
                            allowedTypes: ["png", "jpg", "jpeg", "heic", "tiff", "gif"],
                            onSelect: { url in settings.setCustomImageURL(url) }
                        )

                    case .video:
                        FilePickerRow(
                            label: "Video",
                            path: $settings.customVideoPath,
                            allowedTypes: ["mp4", "mov", "m4v"],
                            onSelect: { url in settings.setCustomVideoURL(url) }
                        )

                    default:
                        EmptyView()
                    }
                } header: {
                    Label(String(localized: "Break Visual"), systemImage: "paintbrush")
                }

                // MARK: - Sound
                Section {
                    Toggle(String(localized: "Start gong (begin of break)"), isOn: $settings.startGongEnabled)
                    Toggle(String(localized: "End gong (end of break)"), isOn: $settings.endGongEnabled)
                } header: {
                    Label(String(localized: "Sound"), systemImage: "bell")
                }

                // MARK: - Behavior
                Section {
                    Toggle(String(localized: "Handcuffs mode"), isOn: $settings.handcuffsMode)
                    Text(String(localized: "When on, ESC and Cmd+Q cannot dismiss the break early."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Toggle(String(localized: "Startclick confirmation"), isOn: $settings.startclickConfirmation)
                    Text(String(localized: "Shows \"Ready to breathe?\" before each break. Decline to skip without affecting your statistics."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Toggle(String(localized: "Skip breaks during audio/video calls"), isOn: $settings.skipDuringMediaUse)
                    Text(String(localized: "When on, breaks won't interrupt while camera or microphone is active."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label(String(localized: "Behavior"), systemImage: "lock")
                }

                // MARK: - Desktop Sync
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(String(localized: "Sync Key (from iPhone)"), text: $settings.syncPassphrase)
                            .textFieldStyle(.roundedBorder)
                        Text(String(localized: "Enter the key from your iPhone's Settings to sync breaks to your phone."))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if SyncKeyManager.shared.isConfigured {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(String(localized: "Connected"))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 2)
                        }
                    }
                } header: {
                    Label(String(localized: "Desktop Sync"), systemImage: "arrow.triangle.2.circlepath.icloud")
                }

                // MARK: - Philosophy
                Section {
                } footer: {
                    Text(String(localized: "The goal of this app is to not need it anymore.\nUntil then: Breathe."))
                        .font(.caption.italic())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(WarmBackground())
        .frame(width: 460, height: 620)
    }

    private func formatHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

// MARK: - Range Slider

/// A custom two-thumb range slider built from two overlapping sliders.
/// The low thumb cannot exceed the high thumb and vice versa.
struct RangeSliderView: View {

    @Binding var low: Double
    @Binding var high: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                // Active range highlight
                let totalWidth = geo.size.width
                let lowFrac = (low - range.lowerBound) / (range.upperBound - range.lowerBound)
                let highFrac = (high - range.lowerBound) / (range.upperBound - range.lowerBound)
                Capsule()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: CGFloat(highFrac - lowFrac) * totalWidth, height: 4)
                    .offset(x: CGFloat(lowFrac) * totalWidth)

                // Low thumb
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(lowFrac) * (totalWidth - 16))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = Double(value.location.x / totalWidth)
                                let newValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                                let stepped = (newValue / step).rounded() * step
                                low = min(max(stepped, range.lowerBound), high)
                            }
                    )

                // High thumb
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(highFrac) * (totalWidth - 16))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = Double(value.location.x / totalWidth)
                                let newValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                                let stepped = (newValue / step).rounded() * step
                                high = max(min(stepped, range.upperBound), low)
                            }
                    )
            }
        }
        .frame(height: 20)
    }
}

// MARK: - File Picker Row

/// A row showing a file path with a "Choose..." button that opens an NSOpenPanel.
/// Uses security-scoped bookmarks so the chosen file remains accessible in the sandbox.
struct FilePickerRow: View {

    let label: String
    @Binding var path: String
    let allowedTypes: [String]
    /// Called after the user picks a file; stores a security-scoped bookmark
    var onSelect: ((URL) -> Void)?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(displayPath)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .trailing)

            if !path.isEmpty {
                Button(role: .destructive) {
                    path = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear selection")
            }

            Button(String(localized: "Choose...")) {
                chooseFile()
            }
        }
    }

    private var displayPath: String {
        if path.isEmpty { return String(localized: "Default") }
        return (path as NSString).lastPathComponent
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedTypes.compactMap {
            UTType(filenameExtension: $0)
        }

        if panel.runModal() == .OK, let url = panel.url {
            onSelect?(url)
            path = url.path
        }
    }
}
