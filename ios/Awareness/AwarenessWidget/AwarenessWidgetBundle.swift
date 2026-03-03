import WidgetKit
import SwiftUI

/// Entry point for the iOS home screen widget extension.
/// Provides systemSmall and systemMedium widgets showing practice card,
/// micro-task, progress donut, and next blackout time.
@main
struct AwarenessWidgetBundle: WidgetBundle {
    var body: some Widget {
        AwarenessHomeWidget()
    }
}
