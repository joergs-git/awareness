import Foundation

/// Defines what the user sees during a blackout overlay
enum BlackoutVisualType: String, CaseIterable, Identifiable {
    case plainBlack = "plainBlack"
    case text = "text"
    case image = "image"
    case video = "video"
    /// Shows the current practice card's user-supplied photo (front/back) at the break end.
    case cardPhoto = "cardPhoto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainBlack: return String(localized: "Plain Black")
        case .text:       return String(localized: "Custom Text")
        case .image:      return String(localized: "Image")
        case .video:      return String(localized: "Video")
        case .cardPhoto:  return String(localized: "Card")
        }
    }
}
