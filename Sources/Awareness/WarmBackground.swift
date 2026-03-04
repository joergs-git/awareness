import SwiftUI

/// Warm gradient background that adapts to light and dark mode.
struct WarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.14, green: 0.12, blue: 0.11),
                   Color(red: 0.10, green: 0.09, blue: 0.08)]
                : [Color(red: 0.98, green: 0.92, blue: 0.84),
                   Color(red: 0.93, green: 0.85, blue: 0.78)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
