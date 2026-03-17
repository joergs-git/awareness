import Foundation

/// Lightweight Supabase REST API client for macOS.
/// Uploads blackout events to Supabase via PostgREST. No third-party dependencies.
final class SupabaseClient {

    static let shared = SupabaseClient()

    // MARK: - Configuration
    // Supabase anon key is a public key by design — RLS policies protect the data.
    // The sync_key hash (SHA-256 of the passphrase) scopes access per user.

    private static let supabaseURL = "https://dntkhnjmczkqluwgddir.supabase.co"
    private static let supabaseAnonKey = "sb_publishable_Ncq1smqygsQIQg4kKe7NqA_IR4xg8Kb"

    /// Event payload for uploading to Supabase
    struct UploadEvent: Codable {
        let syncKey: String
        let startedAt: String
        let duration: Double
        let completed: Bool
        let awareness: String?
        let source: String

        enum CodingKeys: String, CodingKey {
            case syncKey = "sync_key"
            case startedAt = "started_at"
            case duration
            case completed
            case awareness
            case source
        }
    }

    // MARK: - Upload

    /// Upload a single blackout event to Supabase.
    /// Uses ON CONFLICT DO NOTHING for idempotent retries.
    func uploadEvent(_ event: UploadEvent) async throws {
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/blackout_events") else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal,resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(event)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Helpers

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Format a date as ISO 8601
    static func formatDate(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    enum SyncError: Error {
        case invalidURL
        case httpError(Int)
    }

    private init() {}
}
