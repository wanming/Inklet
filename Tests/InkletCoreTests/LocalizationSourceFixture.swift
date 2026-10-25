import Foundation

/// Source text of the localization layer: `InkletLocalization.swift` followed by
/// every language table under `Localization/`, in `L10n.translationTables` order.
enum LocalizationSourceFixture {
    static let tableIDs = ["en", "zhHans", "zhHant", "ja", "ko", "es", "fr", "de", "pt", "it"]

    static func source() throws -> String {
        let appSources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/InkletApp")
        let files = [appSources.appendingPathComponent("InkletLocalization.swift")]
            + tableIDs.map { appSources.appendingPathComponent("Localization/L10n+\($0).swift") }
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }
}
