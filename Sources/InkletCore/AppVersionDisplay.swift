public enum AppVersionDisplay {
    public static func format(
        marketingVersion: String?,
        buildNumber: String?,
        fallback: String
    ) -> String {
        guard let marketingVersion, !marketingVersion.isEmpty else {
            return buildNumber ?? fallback
        }
        guard let buildNumber, !buildNumber.isEmpty else {
            return marketingVersion
        }
        return "\(marketingVersion) (\(buildNumber))"
    }
}
