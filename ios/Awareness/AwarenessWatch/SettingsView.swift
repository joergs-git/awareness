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
                Stepper("Min: \(Int(settings.minInterval))",
                        value: $settings.minInterval, in: 1...120, step: 1)
                Stepper("Max: \(Int(settings.maxInterval))",
                        value: $settings.maxInterval, in: 1...120, step: 1)
            }

            // MARK: - Duration
            Section("Duration (sec)") {
                Stepper("Min: \(Int(settings.minBlackoutDuration))",
                        value: $settings.minBlackoutDuration, in: 3...120, step: 1)
                Stepper("Max: \(Int(settings.maxBlackoutDuration))",
                        value: $settings.maxBlackoutDuration, in: 3...120, step: 1)
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
