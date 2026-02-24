import Foundation

/// Checks GitHub for a newer release of Awareness.
/// Queries the GitHub API once on startup and exposes the result
/// so the menu bar can show an "Update Available" item.
class UpdateChecker {

    static let shared = UpdateChecker()

    /// Whether a newer version is available on GitHub
    private(set) var updateAvailable = false

    /// The latest version string from GitHub (e.g. "1.1"), nil if not yet checked or check failed
    private(set) var latestVersion: String?

    /// URL to the latest release page
    let releaseURL = "https://github.com/joergs-git/awareness/releases/latest"

    private let apiURL = "https://api.github.com/repos/joergs-git/awareness/releases/latest"

    private init() {}

    /// Fetch the latest release tag from GitHub and compare against the running version.
    /// Runs on a background thread; silently ignores any errors.
    /// Skipped when running inside the App Sandbox — the App Store handles updates.
    func check() {
        // In the Mac App Store build (sandboxed), updates are delivered through the store.
        // Showing a "download from GitHub" prompt would be confusing and against App Store guidelines.
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return
        }

        guard let url = URL(string: apiURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("Awareness", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return
            }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

            if UpdateChecker.isVersion(remoteVersion, newerThan: localVersion) {
                DispatchQueue.main.async {
                    self.latestVersion = remoteVersion
                    self.updateAvailable = true
                }
            }
        }.resume()
    }

    /// Compare two dotted version strings numerically (e.g. "1.2" > "1.0", "2.0" > "1.9.9")
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)

        for i in 0..<count {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }

        return false
    }
}
