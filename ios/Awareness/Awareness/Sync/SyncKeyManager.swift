import Foundation
import CryptoKit

/// Manages the sync passphrase used to link desktop and iOS devices via Supabase.
/// iOS generates the passphrase; desktop apps enter it manually.
/// The passphrase is hashed with SHA-256 before being sent to Supabase.
final class SyncKeyManager {

    static let shared = SyncKeyManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let syncPassphrase = "syncPassphrase"
        static let syncLastPullDate = "syncLastPullDate"
        static let syncProcessedEventIDs = "syncProcessedEventIDs"
        static let deviceUUID = "syncDeviceUUID"
    }

    // MARK: - Passphrase

    /// The 4-word + number sync passphrase (e.g. "lotus-ember-cedar-moonrise-42")
    var passphrase: String? {
        get { defaults.string(forKey: Keys.syncPassphrase) }
        set { defaults.set(newValue, forKey: Keys.syncPassphrase) }
    }

    /// Whether sync is configured — true if passphrase exists OR Smart Guru is enabled (device UUID fallback)
    var isConfigured: Bool {
        if let phrase = passphrase, !phrase.isEmpty { return true }
        // When Smart Guru is enabled, always upload using device UUID
        return SettingsManager.shared.smartGuruEnabled
    }

    /// Auto-generated device UUID for anonymous Supabase uploads when no passphrase is set.
    /// Persisted across app launches so the same device always gets the same sync_key.
    var deviceUUID: String {
        if let existing = defaults.string(forKey: Keys.deviceUUID), !existing.isEmpty {
            return existing
        }
        let uuid = UUID().uuidString
        defaults.set(uuid, forKey: Keys.deviceUUID)
        return uuid
    }

    /// SHA-256 hex digest used as the sync_key in Supabase.
    /// Uses passphrase when available (desktop sync), otherwise device UUID (anonymous upload).
    var hashedSyncKey: String? {
        let source: String
        if let phrase = passphrase, !phrase.isEmpty {
            source = phrase.lowercased()
        } else if SettingsManager.shared.smartGuruEnabled {
            source = deviceUUID
        } else {
            return nil
        }
        let data = Data(source.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Generation

    /// Generate a new 4-word + 2-digit number passphrase
    func generatePassphrase() -> String {
        var words: [String] = []
        var usedIndices = Set<Int>()

        // Pick 4 unique random words
        while words.count < 4 {
            let index = Int.random(in: 0..<SyncWordList.words.count)
            if !usedIndices.contains(index) {
                usedIndices.insert(index)
                words.append(SyncWordList.words[index])
            }
        }

        // Add a 2-digit number (10-99)
        let number = Int.random(in: 10...99)
        words.append(String(number))

        let phrase = words.joined(separator: "-")
        passphrase = phrase
        return phrase
    }

    /// Regenerate the passphrase (clears sync state)
    func regeneratePassphrase() -> String {
        clearSyncState()
        return generatePassphrase()
    }

    // MARK: - Sync State

    /// Last successful pull date — used as cursor for fetching new events
    var lastPullDate: Date? {
        get { defaults.object(forKey: Keys.syncLastPullDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.syncLastPullDate) }
    }

    /// Set of processed event UUIDs — prevents double-counting
    var processedEventIDs: Set<String> {
        get {
            let array = defaults.stringArray(forKey: Keys.syncProcessedEventIDs) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.syncProcessedEventIDs)
        }
    }

    /// Clear all sync state (used when regenerating the passphrase)
    func clearSyncState() {
        lastPullDate = nil
        processedEventIDs = []
    }

    private init() {}
}
