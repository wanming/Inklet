import Foundation

/// Decides which release notes to show on the first launch after an update. Versions compare
/// numerically, so 1.10.0 is newer than 1.9.0.
public enum WhatsNewPolicy {
    public static func isNewer(_ version: String, than other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedDescending
    }

    /// The versions with notes that the person hasn't seen yet, newest first. Updating across several
    /// versions shows each of them. Someone updating from a version that didn't record what it showed
    /// sees only the current version's notes. Nothing shows while the welcome guide is open, because
    /// the guide already walks through the app.
    public static func unseenVersions(
        withNotes versions: [String],
        currentVersion: String,
        lastSeenVersion: String?,
        isWelcomeGuideShowing: Bool
    ) -> [String] {
        guard !isWelcomeGuideShowing else { return [] }
        guard let lastSeenVersion else {
            return versions.contains(currentVersion) ? [currentVersion] : []
        }
        return versions
            .filter { isNewer($0, than: lastSeenVersion) && !isNewer($0, than: currentVersion) }
            .sorted { isNewer($0, than: $1) }
    }
}
