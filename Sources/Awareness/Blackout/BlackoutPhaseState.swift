import SwiftUI

/// Tracks the current phase of the blackout overlay after the breathing timer expires.
/// Shared between BlackoutWindowController (which drives transitions) and
/// PostBlackoutView (which renders the content).
enum BlackoutPhase {
    case breathing       // Normal blackout content (breathing animation)
    case awarenessCheck  // "Warst Du da?" — user picks Ja/Etwas/Nein
    case practiceCard    // Card title + micro-task, stays until user clicks
}

/// Observable state object passed to PostBlackoutView.
/// BlackoutWindowController sets the phase; PostBlackoutView reacts to changes.
class BlackoutPhaseState: ObservableObject {
    @Published var phase: BlackoutPhase = .breathing
    var practiceCard: PracticeCard?
    var microTask: MicroTask?

    /// Called when the user answers the awareness check — transitions to practice card
    var onAwarenessAnswered: (() -> Void)?
    /// Called when the user clicks/presses a key to dismiss the card phase
    var onDismissRequest: (() -> Void)?
}
