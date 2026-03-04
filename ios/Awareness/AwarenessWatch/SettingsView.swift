import SwiftUI

/// Compact settings form for Apple Watch.
/// Offers active hours, intervals, duration, visual type (plain/text only),
/// haptic toggles, and handcuffs mode. HealthKit is managed from the iOS companion app.
struct SettingsView: View {

    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        Form {
            // MARK: - Active Hours
            Section(String(localized: "Active Hours")) {
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
            }

            // MARK: - Interval
            Section(String(localized: "Interval (min)")) {
                Picker(String(localized: "Min"), selection: Binding(
                    get: { Int(settings.minInterval) },
                    set: { settings.minInterval = Double($0) }
                )) {
                    ForEach(1...120, id: \.self) { min in
                        Text("\(min)").tag(min)
                    }
                }
                Picker(String(localized: "Max"), selection: Binding(
                    get: { Int(settings.maxInterval) },
                    set: { settings.maxInterval = Double($0) }
                )) {
                    ForEach(1...120, id: \.self) { min in
                        Text("\(min)").tag(min)
                    }
                }
            }

            // MARK: - Duration
            Section(String(localized: "Duration (sec)")) {
                Picker(String(localized: "Min"), selection: Binding(
                    get: { Int(settings.minBlackoutDuration) },
                    set: { settings.minBlackoutDuration = Double($0) }
                )) {
                    ForEach(3...120, id: \.self) { sec in
                        Text("\(sec)").tag(sec)
                    }
                }
                Picker(String(localized: "Max"), selection: Binding(
                    get: { Int(settings.maxBlackoutDuration) },
                    set: { settings.maxBlackoutDuration = Double($0) }
                )) {
                    ForEach(3...120, id: \.self) { sec in
                        Text("\(sec)").tag(sec)
                    }
                }
            }

            // MARK: - Visual
            Section(String(localized: "Visual")) {
                Picker(String(localized: "Style"), selection: $settings.visualType) {
                    Text(String(localized: "Black")).tag(BlackoutVisualType.plainBlack)
                    Text(String(localized: "Text")).tag(BlackoutVisualType.text)
                }
                if settings.visualType == .text {
                    TextField(String(localized: "Text"), text: $settings.customText)
                }
            }

            // MARK: - Feedback
            Section(String(localized: "Feedback")) {
                Toggle(String(localized: "Reminder haptic"), isOn: $settings.reminderHapticEnabled)
                Toggle(String(localized: "End haptic"), isOn: $settings.hapticEndEnabled)
                Toggle(String(localized: "End flash"), isOn: $settings.endFlashEnabled)
            }

            // MARK: - Behavior
            Section {
                Toggle(String(localized: "Handcuffs"), isOn: $settings.handcuffsMode)
            } footer: {
                Text(String(localized: "Prevents dismissing break early."))
            }

        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle(String(localized: "Settings"))
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}
