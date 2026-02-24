import SwiftUI
import PhotosUI

/// iOS-native settings form using NavigationStack and Form.
/// Adapts to iPhone and iPad.
struct SettingsView: View {

    @ObservedObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingVideoImporter = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Active Hours
                Section {
                    Picker("From", selection: $settings.activeStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    Picker("Until", selection: $settings.activeEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                } header: {
                    Label("Active Hours", systemImage: "clock")
                }

                // MARK: - Interval Range
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Min: \(Int(settings.minInterval)) min")
                                .monospacedDigit()
                            Spacer()
                        }
                        Slider(value: $settings.minInterval, in: 1...120, step: 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max: \(Int(settings.maxInterval)) min")
                                .monospacedDigit()
                            Spacer()
                        }
                        Slider(value: $settings.maxInterval, in: 1...120, step: 1)
                    }
                } header: {
                    Label("Interval Between Blackouts", systemImage: "timer")
                }

                // MARK: - Blackout Duration
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Min: \(Int(settings.minBlackoutDuration))s")
                                .monospacedDigit()
                            Spacer()
                        }
                        Slider(value: $settings.minBlackoutDuration, in: 3...120, step: 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max: \(Int(settings.maxBlackoutDuration))s")
                                .monospacedDigit()
                            Spacer()
                        }
                        Slider(value: $settings.maxBlackoutDuration, in: 3...120, step: 1)
                    }
                } header: {
                    Label("Blackout Duration", systemImage: "eye.slash")
                }

                // MARK: - Visual Type
                Section {
                    Picker("Style", selection: $settings.visualType) {
                        ForEach(BlackoutVisualType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch settings.visualType {
                    case .text:
                        TextField("Display text", text: $settings.customText)

                    case .image:
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Text("Choose Image")
                                Spacer()
                                if !settings.customImagePath.isEmpty {
                                    Text("Selected")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Default")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: selectedPhoto, perform: { newValue in
                            handlePhotoSelection(newValue)
                        })

                        if !settings.customImagePath.isEmpty {
                            Button("Clear Selection", role: .destructive) {
                                settings.customImagePath = ""
                            }
                        }

                    case .video:
                        Button {
                            showingVideoImporter = true
                        } label: {
                            HStack {
                                Text("Choose Video")
                                Spacer()
                                if !settings.customVideoPath.isEmpty {
                                    Text("Selected")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("None")
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
                            Button("Clear Selection", role: .destructive) {
                                settings.customVideoPath = ""
                            }
                        }

                    default:
                        EmptyView()
                    }
                } header: {
                    Label("Blackout Visual", systemImage: "paintbrush")
                }

                // MARK: - Feedback
                Section {
                    Toggle("Start gong (begin of blackout)", isOn: $settings.startGongEnabled)
                    Toggle("End gong (end of blackout)", isOn: $settings.endGongEnabled)
                    Toggle("Vibration (start and end)", isOn: $settings.vibrationEnabled)
                    Toggle("End flash (visible through closed eyes)", isOn: $settings.endFlashEnabled)
                } header: {
                    Label("Feedback", systemImage: "bell")
                } footer: {
                    Text("Vibration is useful when the phone is on silent and your eyes are closed.")
                }

                // MARK: - Behavior
                Section {
                    Toggle("Handcuffs mode", isOn: $settings.handcuffsMode)
                } header: {
                    Label("Behavior", systemImage: "lock")
                } footer: {
                    Text("When on, tap cannot dismiss the blackout early.")
                }

                // MARK: - Health
                Section {
                    Toggle("Log to Apple Health", isOn: $settings.healthKitEnabled)
                        .onChange(of: settings.healthKitEnabled, perform: { enabled in
                            if enabled {
                                Task { await HealthKitManager.shared.requestAuthorization() }
                            }
                        })
                } header: {
                    Label("Health", systemImage: "heart.fill")
                } footer: {
                    Text("Records each mindful pause as Mindful Minutes in Apple Health.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
