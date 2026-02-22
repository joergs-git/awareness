import Foundation

/// Defines what the user sees during a blackout overlay
enum BlackoutVisualType: String, CaseIterable, Identifiable {
    case plainBlack = "plainBlack"
    case text = "text"
    case image = "image"
    case video = "video"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainBlack: return "Plain Black"
        case .text:       return "Custom Text"
        case .image:      return "Image"
        case .video:      return "Video"
        }
    }
}
