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

    /// Event received from Supabase (used for pre-trigger check and pull sync)
    struct RemoteEvent: Codable {
        let id: Int?
        let startedAt: String
        let duration: Double
        let completed: Bool?
        let awareness: String?
        let source: String
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case startedAt = "started_at"
            case duration
            case completed
            case awareness
            case source
            case createdAt = "created_at"
        }
    }

    // MARK: - Fetch Recent Events (pre-trigger check)

    /// Fetch recent events from other platforms for the given sync key.
    /// Used to check if another device had a break recently, preventing double-triggering.
    func fetchRecentEvents(syncKeyHash: String, since: Date) async throws -> [RemoteEvent] {
        let iso = Self.formatDate(since)
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/blackout_events"
            + "?sync_key=eq.\(syncKeyHash)"
            + "&source=neq.macos"
            + "&started_at=gt.\(iso)"
            + "&select=id,started_at,duration,completed,awareness,source,created_at"
            + "&order=started_at.desc"
            + "&limit=5") else {
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

        return try JSONDecoder().decode([RemoteEvent].self, from: data)
    }

    // MARK: - Fetch Events for Pull Sync

    /// Fetch all events from other platforms since a given cursor date.
    /// Used to pull remote events into local ProgressTracker for unified stats.
    func fetchEvents(syncKeyHash: String, since: Date, excludeSource: String) async throws -> [RemoteEvent] {
        let iso = Self.formatDate(since)
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/blackout_events"
            + "?sync_key=eq.\(syncKeyHash)"
            + "&source=neq.\(excludeSource)"
            + "&created_at=gt.\(iso)"
            + "&select=id,started_at,duration,completed,awareness,source,created_at"
            + "&order=created_at.asc") else {
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

        return try JSONDecoder().decode([RemoteEvent].self, from: data)
    }

    // MARK: - Upload

    /// Upload a single blackout event to Supabase.
    /// Uses ON CONFLICT DO NOTHING for idempotent retries.
    func uploadEvent(_ event: UploadEvent) async throws {
        // on_conflict enables upsert: INSERT or UPDATE when (sync_key, started_at, source) matches
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/blackout_events?on_conflict=sync_key,started_at,source") else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.addValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(event)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Storage (card photos)
    // Opt-in card-photo sync. Objects live under "{sync_key_hash}/..." in a private bucket;
    // RLS restricts each anon client to its own prefix (same trust model as blackout_events).

    static let cardBucket = "card-assets"

    /// A single object returned by the Storage list endpoint.
    struct StorageObject: Codable {
        let name: String
        let metadata: Meta?
        struct Meta: Codable { let size: Int? }
    }

    /// Upload (upsert) raw bytes to the card-assets bucket at the given path.
    func uploadStorageObject(path: String, data: Data, contentType: String) async throws {
        guard let url = URL(string: "\(Self.supabaseURL)/storage/v1/object/\(Self.cardBucket)/\(path)") else {
            throw SyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    /// Download an object's bytes. Returns nil when the object is absent (404).
    func downloadStorageObject(path: String) async throws -> Data? {
        guard let url = URL(string: "\(Self.supabaseURL)/storage/v1/object/\(Self.cardBucket)/\(path)") else {
            throw SyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.httpError(0) }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else { throw SyncError.httpError(http.statusCode) }
        return data
    }

    /// List objects under a prefix (e.g. "{hash}/") in the card-assets bucket.
    func listStorageObjects(prefix: String) async throws -> [StorageObject] {
        guard let url = URL(string: "\(Self.supabaseURL)/storage/v1/object/list/\(Self.cardBucket)") else {
            throw SyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "prefix": prefix,
            "limit": 100
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return (try? JSONDecoder().decode([StorageObject].self, from: data)) ?? []
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

    /// Parse an ISO 8601 date string
    static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }

    enum SyncError: Error {
        case invalidURL
        case httpError(Int)
    }

    private init() {}
}

// MARK: - Card Asset Sync (downloader)

/// Pulls user card photos + manual card selection from Supabase Storage into the local
/// store. Opt-in (`cardPhotoSyncEnabled`). macOS is a consumer: iOS is the typical author,
/// but any device that has the photos locally can also have uploaded them.
final class CardAssetSync {

    static let shared = CardAssetSync()
    private init() {}

    private var isSyncing = false
    private var isPushing = false

    private struct Manifest: Codable { var manualCardID: String? }

    /// Upload every local card photo (upsert) plus a tiny manifest carrying the manual
    /// card selection. Union model: uploads never delete remote objects, so multiple
    /// devices' photos accumulate without clobbering each other.
    func pushIfEnabled() {
        let settings = SettingsManager.shared
        guard settings.cardPhotoSyncEnabled,
              let hash = SyncKeyManager.shared.hashedSyncKey,
              !isPushing else { return }
        isPushing = true

        Task {
            defer { isPushing = false }
            do {
                for card in PracticeCard.allCards {
                    for side in CardPhotoSide.allCases {
                        guard settings.hasCardPhoto(cardID: card.id, side: side),
                              let data = try? Data(contentsOf: settings.cardPhotoURL(cardID: card.id, side: side)) else { continue }
                        try await SupabaseClient.shared.uploadStorageObject(
                            path: "\(hash)/card-\(card.id)-\(side.rawValue).png",
                            data: data,
                            contentType: "image/png")
                    }
                }
                let manualID = settings.manualCardSelectionEnabled ? settings.manualCardID : ""
                let manifest = try JSONEncoder().encode(Manifest(manualCardID: manualID))
                try await SupabaseClient.shared.uploadStorageObject(
                    path: "\(hash)/manifest.json",
                    data: manifest,
                    contentType: "application/json")
            } catch {
                // Non-fatal — retry on next change/launch.
            }
        }
    }

    /// Download card photos + manual selection from Supabase into the local store.
    func pullIfEnabled() {
        let settings = SettingsManager.shared
        guard settings.cardPhotoSyncEnabled,
              let hash = SyncKeyManager.shared.hashedSyncKey,
              !isSyncing else { return }
        isSyncing = true

        Task { @MainActor in
            defer { isSyncing = false }
            do {
                let objects = try await SupabaseClient.shared.listStorageObjects(prefix: "\(hash)/")
                for obj in objects {
                    guard let (cardID, side) = Self.parse(fileName: obj.name) else { continue }
                    let localURL = settings.cardPhotoURL(cardID: cardID, side: side)
                    let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
                    let localSize = attrs?[.size] as? Int
                    // Download when missing locally or the remote size differs (updated elsewhere).
                    if localSize == nil || localSize != obj.metadata?.size {
                        if let data = try await SupabaseClient.shared.downloadStorageObject(path: "\(hash)/\(obj.name)") {
                            settings.writeCardPhoto(cardID: cardID, side: side, data: data)
                        }
                    }
                }
                // Apply the synced manual card selection, if any.
                if let mData = try await SupabaseClient.shared.downloadStorageObject(path: "\(hash)/manifest.json"),
                   let manifest = try? JSONDecoder().decode(Manifest.self, from: mData),
                   let manualID = manifest.manualCardID, !manualID.isEmpty {
                    settings.manualCardSelectionEnabled = true
                    settings.manualCardID = manualID
                }
            } catch {
                // Non-fatal — retry on next launch.
            }
        }
    }

    /// Parse "card-<id>-<side>.png" (id may contain hyphens) into (cardID, side).
    private static func parse(fileName: String) -> (String, CardPhotoSide)? {
        guard fileName.hasPrefix("card-"), fileName.hasSuffix(".png") else { return nil }
        let core = String(fileName.dropFirst("card-".count).dropLast(".png".count))
        if core.hasSuffix("-front") { return (String(core.dropLast("-front".count)), .front) }
        if core.hasSuffix("-back") { return (String(core.dropLast("-back".count)), .back) }
        return nil
    }
}
