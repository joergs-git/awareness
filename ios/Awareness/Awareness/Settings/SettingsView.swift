import SwiftUI
import PhotosUI

/// iOS-native settings form using NavigationStack and Form.
/// Adapts to iPhone and iPad.
struct SettingsView: View {

    @ObservedObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingVideoImporter = false
    @State private var showingRegenerateConfirmation = false
    /// Tracks the current sync passphrase for reactivity (SyncKeyManager is not observable)
    @State private var syncPassphrase: String? = SyncKeyManager.shared.passphrase
    @ObservedObject private var syncManager = SyncManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Active Hours
                Section {
                    Picker(String(localized: "From"), selection: $settings.activeStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    Picker(String(localized: "Until"), selection: $settings.activeEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                } header: {
                    Label(String(localized: "Active Hours"), systemImage: "clock")
                }

                // MARK: - Smart Guru
                Section {
                    Toggle(String(localized: "Smart Guru"), isOn: $settings.smartGuruEnabled)

                    if settings.smartGuruEnabled {
                        // Show adaptive status info instead of sliders
                        HStack {
                            Text(String(localized: "Status"))
                            Spacer()
                            Text(SmartGuru.shared.statusDescription(state: settings.guruAdaptiveState))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        HStack {
                            Text(String(localized: "Interval"))
                            Spacer()
                            Text(String(localized: "\(Int(settings.effectiveMinInterval))–\(Int(settings.effectiveMaxInterval)) min"))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }

                        HStack {
                            Text(String(localized: "Duration"))
                            Spacer()
                            Text(String(localized: "\(Int(settings.effectiveMinDuration))–\(Int(settings.effectiveMaxDuration))s"))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Label(String(localized: "Adaptive Scheduling"), systemImage: "brain.head.profile")
                } footer: {
                    Text(String(localized: "When enabled, the guru learns your rhythm and adjusts intervals and duration automatically. Anonymous practice data (timestamps, durations, scores — no personal info) is uploaded to help improve the algorithm."))
                }

                // MARK: - Setup Guide
                Section {
                    Button {
                        dismiss()
                        // Small delay to let settings sheet dismiss, then show guide
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            NotificationCenter.default.post(name: .showSetupGuide, object: nil)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(red: 0.55, green: 0.38, blue: 0.72))
                            Text(String(localized: "Important for you."))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text(String(localized: "Tips to optimize your device for a focused mindfulness practice."))
                }

                // MARK: - Desktop Sync
                Section {
                    Toggle(String(localized: "I also work on a computer"), isOn: $settings.worksOnComputer)

                    if settings.worksOnComputer {
                        if let phrase = syncPassphrase, !phrase.isEmpty {
                            HStack {
                                Text(String(localized: "Status"))
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(syncManager.isSyncOnline ? .green : .gray)
                                        .font(.caption)
                                    Text(syncManager.isSyncOnline
                                         ? String(localized: "Connected")
                                         : String(localized: "Not connected"))
                                        .font(.caption)
                                        .foregroundColor(syncManager.isSyncOnline ? .green : .secondary)
                                }
                            }

                            HStack {
                                Text(String(localized: "Sync Key"))
                                Spacer()
                                Text(phrase)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                UIPasteboard.general.string = phrase
                            } label: {
                                Label(String(localized: "Copy to Clipboard"), systemImage: "doc.on.doc")
                            }

                            Button(role: .destructive) {
                                showingRegenerateConfirmation = true
                            } label: {
                                Label(String(localized: "Regenerate Key"), systemImage: "arrow.triangle.2.circlepath")
                            }
                        } else {
                            Button {
                                syncPassphrase = SyncKeyManager.shared.generatePassphrase()
                            } label: {
                                Label(String(localized: "Generate Sync Key"), systemImage: "key")
                            }
                        }
                    }
                } header: {
                    Label(String(localized: "Desktop Sync"), systemImage: "arrow.triangle.2.circlepath.icloud")
                } footer: {
                    if settings.worksOnComputer {
                        Text(String(localized: "Generate a sync key and enter it in the Mac or Windows app. Your desktop breaks will then count toward your iPhone stats and Apple Health. Anonymous, no account needed."))
                    } else {
                        Text(String(localized: "If you also use Atempause on Mac or Windows, you can sync your desktop breaks to this device."))
                    }
                }

                // MARK: - Interval Range (hidden when guru is active)
                if !settings.smartGuruEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(String(localized: "Min: \(Int(settings.minInterval)) min"))
                                    .monospacedDigit()
                                Spacer()
                            }
                            Slider(value: $settings.minInterval, in: 1...120, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(String(localized: "Max: \(Int(settings.maxInterval)) min"))
                                    .monospacedDigit()
                                Spacer()
                            }
                            Slider(value: $settings.maxInterval, in: 1...120, step: 1)
                        }
                    } header: {
                        Label(String(localized: "Interval Between Breaks"), systemImage: "timer")
                    }

                    // MARK: - Blackout Duration
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(String(localized: "Min: \(Int(settings.minBlackoutDuration))s"))
                                    .monospacedDigit()
                                Spacer()
                            }
                            Slider(value: $settings.minBlackoutDuration, in: 3...120, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(String(localized: "Max: \(Int(settings.maxBlackoutDuration))s"))
                                    .monospacedDigit()
                                Spacer()
                            }
                            Slider(value: $settings.maxBlackoutDuration, in: 3...120, step: 1)
                        }
                    } header: {
                        Label(String(localized: "Break Duration"), systemImage: "eye.slash")
                    }
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

                    case .image:
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Text(String(localized: "Choose Image"))
                                Spacer()
                                if !settings.customImagePath.isEmpty {
                                    Text(String(localized: "Selected"))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(String(localized: "Default"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: selectedPhoto, perform: { newValue in
                            handlePhotoSelection(newValue)
                        })

                        if !settings.customImagePath.isEmpty {
                            Button(String(localized: "Clear Selection"), role: .destructive) {
                                settings.customImagePath = ""
                            }
                        }

                    case .video:
                        Button {
                            showingVideoImporter = true
                        } label: {
                            HStack {
                                Text(String(localized: "Choose Video"))
                                Spacer()
                                if !settings.customVideoPath.isEmpty {
                                    Text(String(localized: "Selected"))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(String(localized: "None"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .fileImporter(
                            isPresented: $showingVideoImporter,
                            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                            allowsMultipleSelection: false
                        ) { result in
                            if case .success(let urls) = result, let url = urls.first {
                                settings.customVideoPath = url.path
                            }
                        }

                        if !settings.customVideoPath.isEmpty {
                            Button(String(localized: "Clear Selection"), role: .destructive) {
                                settings.customVideoPath = ""
                            }
                        }

                    default:
                        EmptyView()
                    }
                } header: {
                    Label(String(localized: "Break Visual"), systemImage: "paintbrush")
                }

                // MARK: - Feedback
                Section {
                    Toggle(String(localized: "Start gong (begin of break)"), isOn: $settings.startGongEnabled)
                    Toggle(String(localized: "End gong (end of break)"), isOn: $settings.endGongEnabled)
                    Toggle(String(localized: "Vibration (start and end)"), isOn: $settings.vibrationEnabled)
                    Toggle(String(localized: "End flash (visible through closed eyes)"), isOn: $settings.endFlashEnabled)
                } header: {
                    Label(String(localized: "Feedback"), systemImage: "bell")
                } footer: {
                    Text(String(localized: "Vibration is useful when the phone is on silent and your eyes are closed."))
                }

                // MARK: - Behavior
                Section {
                    Toggle(String(localized: "Handcuffs mode"), isOn: $settings.handcuffsMode)
                    Toggle(String(localized: "Skip during calls"), isOn: $settings.skipDuringCalls)
                } header: {
                    Label(String(localized: "Behavior"), systemImage: "lock")
                } footer: {
                    Text(String(localized: "Handcuffs: tap cannot dismiss the break early. Skip during calls: no breaks while on a phone or video call (FaceTime, Zoom, etc)."))
                }

                // MARK: - Health
                Section {
                    Toggle(String(localized: "Log to Apple Health"), isOn: $settings.healthKitEnabled)
                        .onChange(of: settings.healthKitEnabled, perform: { enabled in
                            if enabled {
                                Task { await HealthKitManager.shared.requestAuthorization() }
                            }
                        })
                } header: {
                    Label(String(localized: "Health"), systemImage: "heart.fill")
                } footer: {
                    Text(String(localized: "Records each mindful pause as Mindful Minutes in Apple Health."))
                }

                // MARK: - Philosophy
                Section {
                } footer: {
                    Text(String(localized: "The goal of this app is to not need it anymore.\nUntil then: Breathe."))
                        .font(.footnote.italic())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "Regenerate Sync Key?"), isPresented: $showingRegenerateConfirmation) {
                Button(String(localized: "Regenerate"), role: .destructive) {
                    // Pull latest data with the old key before regenerating
                    SyncManager.shared.pullAndIntegrate()
                    syncPassphrase = SyncKeyManager.shared.regeneratePassphrase()
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "This will pull the latest desktop data and then create a new sync key. You must enter the new key on your Mac or Windows app before it will work again — otherwise desktop breaks will be lost in transit."))
            }
        }
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    /// Save a selected photo to the app's documents directory
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data = data {
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsDir.appendingPathComponent("custom-blackout-image.png")
                try? data.write(to: fileURL)
                DispatchQueue.main.async {
                    settings.customImagePath = fileURL.path
                }
            }
        }
    }
}
