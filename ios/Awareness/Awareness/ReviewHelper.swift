import StoreKit
import UIKit

/// Handles App Store review prompts at key milestones.
/// Uses SKStoreReviewController which is native, auto-localized, and Apple rate-limits automatically.
enum ReviewHelper {

    /// Request a review if the user just crossed a milestone (30, 50, 100 completed breaks).
    /// Delays 2 seconds to let the post-blackout UI settle before showing the prompt.
    static func requestReviewIfEligible() {
        guard ProgressTracker.shared.shouldRequestReview() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
