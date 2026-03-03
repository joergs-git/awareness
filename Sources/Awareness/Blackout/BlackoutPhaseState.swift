import SwiftUI

/// Tracks the current phase of the blackout overlay after the breathing timer expires.
/// Shared between BlackoutWindowController (which drives transitions) and
/// PostBlackoutView (which renders the content).
enum BlackoutPhase {
    case breathing     // Normal blackout content (breathing animation)
    case namaste       // 🙏 shown for 1.5s after breathing completes
    case practiceCard  // Card title + micro-task, stays until user clicks
}

/// Observable state object passed to PostBlackoutView.
/// BlackoutWindowController sets the phase; PostBlackoutView reacts to changes.
class BlackoutPhaseState: ObservableObject {
    @Published var phase: BlackoutPhase = .breathing
    var practiceCard: PracticeCard?
    var microTask: MicroTask?

    /// Called when the user clicks/presses a key to dismiss the card phase
    var onDismissRequest: (() -> Void)?
}
