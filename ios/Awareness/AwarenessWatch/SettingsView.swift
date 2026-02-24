import SwiftUI

/// Compact settings form for Apple Watch.
/// Offers active hours, intervals, duration, visual type (plain/text only),
/// haptic toggles, handcuffs mode, and HealthKit toggle.
struct SettingsView: View {

    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        Form {
            // MARK: - Active Hours
            Section("Active Hours") {
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
            }

            // MARK: - Interval
            Section("Interval (min)") {
                Picker("Min", selection: Binding(
                    get: { Int(settings.minInterval) },
                    set: { settings.minInterval = Double($0) }
                )) {
                    ForEach(1...120, id: \.self) { min in
                        Text("\(min)").tag(min)
                    }
                }
                Picker("Max", selection: Binding(
                    get: { Int(settings.maxInterval) },
                    set: { settings.maxInterval = Double($0) }
                )) {
                    ForEach(1...120, id: \.self) { min in
                        Text("\(min)").tag(min)
                    }
                }
            }

            // MARK: - Duration
            Section("Duration (sec)") {
                Picker("Min", selection: Binding(
                    get: { Int(settings.minBlackoutDuration) },
                    set: { settings.minBlackoutDuration = Double($0) }
                )) {
                    ForEach(3...120, id: \.self) { sec in
                        Text("\(sec)").tag(sec)
                    }
                }
                Picker("Max", selection: Binding(
                    get: { Int(settings.maxBlackoutDuration) },
                    set: { settings.maxBlackoutDuration = Double($0) }
                )) {
                    ForEach(3...120, id: \.self) { sec in
                        Text("\(sec)").tag(sec)
                    }
                }
            }

            // MARK: - Visual
            Section("Visual") {
                Picker("Style", selection: $settings.visualType) {
                    Text("Black").tag(BlackoutVisualType.plainBlack)
                    Text("Text").tag(BlackoutVisualType.text)
                }
                if settings.visualType == .text {
                    TextField("Text", text: $settings.customText)
                }
            }

            // MARK: - Haptics
            Section("Haptics") {
                Toggle("Start haptic", isOn: $settings.hapticStartEnabled)
                Toggle("End haptic", isOn: $settings.hapticEndEnabled)
            }

            // MARK: - Behavior
            Section {
                Toggle("Handcuffs", isOn: $settings.handcuffsMode)
            } footer: {
                Text("Prevents dismissing blackout early.")
            }

            // MARK: - Health
            Section {
                Toggle("Apple Health", isOn: $settings.healthKitEnabled)
                    .onChange(of: settings.healthKitEnabled, perform: { enabled in
                        if enabled {
                            Task { await HealthKitManager.shared.requestAuthorization() }
                        }
                    })
            } footer: {
                Text("Log mindful minutes to Health.")
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}
