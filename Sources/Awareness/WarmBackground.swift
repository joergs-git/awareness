import SwiftUI

/// Warm gradient background that adapts to light and dark mode.
struct WarmBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.14, green: 0.10, blue: 0.20),
                   Color(red: 0.09, green: 0.07, blue: 0.14)]
                : [Color(red: 0.94, green: 0.91, blue: 0.98),
                   Color(red: 0.88, green: 0.84, blue: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
