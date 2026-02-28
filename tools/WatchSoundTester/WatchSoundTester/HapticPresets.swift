import WatchKit

/// A single haptic event — one tap with a type and delay before it fires.
struct HapticEvent {
    /// The WatchKit haptic type to play
    let type: WKHapticType

    /// Delay in seconds before this event fires (relative to the previous event)
    let delayBefore: Double

    init(_ type: WKHapticType, delay: Double = 0.0) {
        self.type = type
        self.delayBefore = delay
    }
}

/// A named haptic pattern consisting of sequential haptic events.
struct HapticPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let events: [HapticEvent]
}

/// Plays haptic patterns by scheduling events with delays.
class HapticPlayer {
    static let shared = HapticPlayer()
    private var workItems: [DispatchWorkItem] = []

    private init() {}

    /// Play a haptic preset — schedules all events with their respective delays.
    func play(_ preset: HapticPreset) {
        stop()

        var cumulativeDelay: Double = 0.0

        for event in preset.events {
            cumulativeDelay += event.delayBefore

            let item = DispatchWorkItem {
                WKInterfaceDevice.current().play(event.type)
            }
            workItems.append(item)

            DispatchQueue.main.asyncAfter(
                deadline: .now() + cumulativeDelay,
                execute: item
            )
        }
    }

    /// Cancel all pending haptic events.
    func stop() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
    }
}

/// Predefined haptic patterns for testing start and end signals.
enum HapticPresets {

    // MARK: - Start Patterns (gentle, calming)

    static let startPatterns: [HapticPreset] = [
        currentStart,
        singleStart,
        doubleDirectionUp,
        clickThenSuccess,
        singleNotification
    ]

    /// Current Awareness behavior: 3× .success with 0.4s gaps
    static let currentStart = HapticPreset(
        name: "3× Success (current)",
        description: "Current: 3× .success, 0.4s gaps",
        events: [
            HapticEvent(.success),
            HapticEvent(.success, delay: 0.4),
            HapticEvent(.success, delay: 0.4)
        ]
    )

    /// Single decisive start tap
    static let singleStart = HapticPreset(
        name: "Single Start",
        description: "One .start tap",
        events: [
            HapticEvent(.start)
        ]
    )

    /// Two upward-feeling taps
    static let doubleDirectionUp = HapticPreset(
        name: "2× Direction Up",
        description: "2× .directionUp, 0.3s gaps",
        events: [
            HapticEvent(.directionUp),
            HapticEvent(.directionUp, delay: 0.3)
        ]
    )

    /// Click then pause then success — builds anticipation
    static let clickThenSuccess = HapticPreset(
        name: "Click → Success",
        description: ".click, pause, then .success",
        events: [
            HapticEvent(.click),
            HapticEvent(.success, delay: 0.6)
        ]
    )

    /// Single notification tap — strong but singular
    static let singleNotification = HapticPreset(
        name: "Single Notification",
        description: "One .notification tap",
        events: [
            HapticEvent(.notification)
        ]
    )

    // MARK: - End Patterns (awakening, signaling return)

    static let endPatterns: [HapticPreset] = [
        currentEnd,
        singleStop,
        tripleDirectionDown,
        retryThenSuccess,
        doubleFailure
    ]

    /// Current Awareness behavior: 4× .notification with 0.3s gaps
    static let currentEnd = HapticPreset(
        name: "4× Notification (current)",
        description: "Current: 4× .notification, 0.3s gaps",
        events: [
            HapticEvent(.notification),
            HapticEvent(.notification, delay: 0.3),
            HapticEvent(.notification, delay: 0.3),
            HapticEvent(.notification, delay: 0.3)
        ]
    )

    /// Single decisive stop tap
    static let singleStop = HapticPreset(
        name: "Single Stop",
        description: "One .stop tap",
        events: [
            HapticEvent(.stop)
        ]
    )

    /// Three downward-feeling taps — winding down
    static let tripleDirectionDown = HapticPreset(
        name: "3× Direction Down",
        description: "3× .directionDown, 0.3s gaps",
        events: [
            HapticEvent(.directionDown),
            HapticEvent(.directionDown, delay: 0.3),
            HapticEvent(.directionDown, delay: 0.3)
        ]
    )

    /// Retry then success — "try again, you did it"
    static let retryThenSuccess = HapticPreset(
        name: "Retry → Success",
        description: ".retry then .success",
        events: [
            HapticEvent(.retry),
            HapticEvent(.success, delay: 0.4)
        ]
    )

    /// Two strong failure taps — firm wake-up call
    static let doubleFailure = HapticPreset(
        name: "2× Failure",
        description: "2× .failure, 0.4s gaps",
        events: [
            HapticEvent(.failure),
            HapticEvent(.failure, delay: 0.4)
        ]
    )
}
