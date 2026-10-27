public enum AppVersionDisplay {
    /// Beta builds carry `InkletReleaseChannel = beta` in Info.plist; every other build is stable.
    public static let releaseChannelInfoKey = "InkletReleaseChannel"

    public static func isBeta(releaseChannel: String?) -> Bool {
        releaseChannel == "beta"
    }

    public static func format(
        marketingVersion: String?,
        buildNumber: String?,
        fallback: String,
        isBeta: Bool = false
    ) -> String {
        guard let marketingVersion, !marketingVersion.isEmpty else {
            return buildNumber ?? fallback
        }
        let version = isBeta ? "\(marketingVersion) Beta" : marketingVersion
        guard let buildNumber, !buildNumber.isEmpty else {
            return version
        }
        return "\(version) (\(buildNumber))"
    }
}
