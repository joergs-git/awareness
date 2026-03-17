import Foundation

/// Lightweight Supabase REST API client using URLSession.
/// No third-party dependencies — communicates directly with PostgREST.
final class SupabaseClient {

    static let shared = SupabaseClient()

    // MARK: - Configuration
    // Supabase anon key is a public key by design — RLS policies protect the data.
    // The sync_key hash (SHA-256 of the passphrase) scopes access per user.

    private static let supabaseURL = "https://dntkhnjmczkqluwgddir.supabase.co"
    private static let supabaseAnonKey = "sb_publishable_Ncq1smqygsQIQg4kKe7NqA_IR4xg8Kb"

    /// Remote blackout event received from Supabase
    struct RemoteEvent: Codable {
        let id: String
        let syncKey: String
        let startedAt: String      // ISO 8601 timestamp
        let duration: Double       // seconds
        let completed: Bool
        let awareness: String?     // "yes" / "somewhat" / "no" / null
        let source: String         // "macos" / "windows"
        let createdAt: String      // ISO 8601 timestamp

        enum CodingKeys: String, CodingKey {
            case id
            case syncKey = "sync_key"
            case startedAt = "started_at"
            case duration
            case completed
            case awareness
            case source
            case createdAt = "created_at"
        }
    }

    /// Event payload for uploading from desktop (macOS)
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

    // MARK: - Fetch Events (iOS pulls from Supabase)

    /// Fetch all events for the given sync key that were created after the given date.
    /// Only returns events from desktop sources (macos/windows), not iOS.
    func fetchEvents(syncKeyHash: String, since: Date?) async throws -> [RemoteEvent] {
        var urlString = "\(Self.supabaseURL)/rest/v1/blackout_events"
            + "?sync_key=eq.\(syncKeyHash)"
            + "&source=neq.ios"
            + "&order=created_at.asc"

        if let since = since {
            let iso = Self.iso8601Formatter.string(from: since)
            urlString += "&created_at=gt.\(iso)"
        }

        guard let url = URL(string: urlString) else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([RemoteEvent].self, from: data)
    }

    // MARK: - Upload Event (macOS/Windows push to Supabase)

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

    /// Parse an ISO 8601 date string
    static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }

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
