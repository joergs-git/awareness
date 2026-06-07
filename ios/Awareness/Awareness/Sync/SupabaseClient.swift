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
        let awareness: String?     // "0"–"100" score or legacy "yes"/"somewhat"/"no" / null
        let source: String         // "macos" / "windows" / "ios" / "watchos"
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

    // MARK: - Fetch Events (iOS pulls from Supabase)

    /// Fetch events for the given sync key that were created after the given date.
    /// Excludes the specified sources to avoid pulling own events.
    func fetchEvents(syncKeyHash: String, since: Date?, excludeSources: [String] = ["ios"]) async throws -> [RemoteEvent] {
        var urlString = "\(Self.supabaseURL)/rest/v1/blackout_events"
            + "?sync_key=eq.\(syncKeyHash)"
            + "&order=created_at.asc"

        // Build source exclusion filter
        if excludeSources.count == 1 {
            urlString += "&source=neq.\(excludeSources[0])"
        } else if excludeSources.count > 1 {
            urlString += "&source=not.in.(\(excludeSources.joined(separator: ",")))"
        }

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

    // MARK: - Upload Event

    /// Upload a single blackout event to Supabase.
    /// Uses upsert (ON CONFLICT merge) so the same event can be updated
    /// (e.g. upload at blackout start with completed=false, then update at end with completed=true).
    func uploadEvent(_ event: UploadEvent) async throws {
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/blackout_events?on_conflict=sync_key,started_at,source") else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use separate addValue calls — some PostgREST versions misparse combined Prefer values
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

    // MARK: - Connectivity Check

    /// Lightweight connectivity check — fetches zero rows to verify Supabase is reachable.
    func checkConnectivity(syncKeyHash: String) async -> Bool {
        let urlString = "\(Self.supabaseURL)/rest/v1/blackout_events?sync_key=eq.\(syncKeyHash)&limit=0"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
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
        request.httpBody = try JSONSerialization.data(withJSONObject: ["prefix": prefix, "limit": 100])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return (try? JSONDecoder().decode([StorageObject].self, from: data)) ?? []
    }

    enum SyncError: Error {
        case invalidURL
        case httpError(Int)
    }

    private init() {}
}

// MARK: - Card Asset Sync (uploader + downloader)

/// Syncs user card photos + manual card selection via Supabase Storage. Opt-in
/// (`cardPhotoSyncEnabled`). iOS is the typical author (photos picked here), but the
/// model is symmetric: every device uploads its own photos (upsert, never deleting
/// remote — union) and downloads the rest. Uses the same sync key as event sync, so the
/// user must have linked their devices via the sync passphrase for cross-device transfer.
final class CardAssetSync {

    static let shared = CardAssetSync()
    private init() {}

    private var isPushing = false
    private var isSyncing = false

    private struct Manifest: Codable { var manualCardID: String? }

    /// Upload every local card photo (upsert) plus a manifest carrying the manual selection.
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
                    if localSize == nil || localSize != obj.metadata?.size {
                        if let data = try await SupabaseClient.shared.downloadStorageObject(path: "\(hash)/\(obj.name)") {
                            settings.writeCardPhoto(cardID: cardID, side: side, data: data)
                        }
                    }
                }
                // Only adopt the synced manual selection when this device has none pinned —
                // never clobber an active local choice the user just made.
                if !settings.manualCardSelectionEnabled,
                   let mData = try await SupabaseClient.shared.downloadStorageObject(path: "\(hash)/manifest.json"),
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
