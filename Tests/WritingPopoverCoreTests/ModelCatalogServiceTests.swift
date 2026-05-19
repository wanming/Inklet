import XCTest
@testable import WritingPopoverCore

final class ModelCatalogServiceTests: XCTestCase {
    private let suiteName = "ModelCatalogServiceTests.\(UUID().uuidString)"
    private var userDefaults: UserDefaults!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    func testRefreshStoresTextOutputModelsForSupportedProviders() async throws {
        let service = ModelCatalogService(
            userDefaults: userDefaults,
            now: { self.now },
            fetchData: { _ in Self.fixtureData }
        )

        try await service.refreshIfNeeded()

        XCTAssertEqual(service.cachedModelIDs(for: "openai"), ["gpt-5.2", "gpt-4.1-mini"])
        XCTAssertEqual(service.cachedModelIDs(for: "gemini"), ["gemini-3.5-flash"])
        XCTAssertNil(service.cachedModelIDs(for: "custom-openai-compatible"))
    }

    func testRefreshIsSkippedWhenCacheIsFresh() async throws {
        var fetchCount = 0
        let service = ModelCatalogService(
            userDefaults: userDefaults,
            now: { self.now },
            fetchData: { _ in
                fetchCount += 1
                return Self.fixtureData
            }
        )

        try await service.refreshIfNeeded()
        try await service.refreshIfNeeded()

        XCTAssertEqual(fetchCount, 1)
    }

    func testRefreshAfterOneDayPreservesExistingCacheWhenFetchFails() async throws {
        var shouldFail = false
        let service = ModelCatalogService(
            userDefaults: userDefaults,
            now: { self.now },
            fetchData: { _ in
                if shouldFail {
                    throw URLError(.notConnectedToInternet)
                }
                return Self.fixtureData
            }
        )

        try await service.refreshIfNeeded()
        now = now.addingTimeInterval(86_401)
        shouldFail = true

        try await service.refreshIfNeeded()

        XCTAssertEqual(service.cachedModelIDs(for: "openai"), ["gpt-5.2", "gpt-4.1-mini"])
    }

    func testCachedModelsUseBundledFallbackWhenUserDefaultsCacheIsEmpty() {
        let service = ModelCatalogService(
            userDefaults: userDefaults,
            bundledFallbackData: { Self.bundledFallbackData },
            now: { self.now },
            fetchData: { _ in Self.fixtureData }
        )

        XCTAssertEqual(service.cachedModelIDs(for: "openai"), ["gpt-5.2"])
    }

    func testDefaultServiceReadsBundledModelSnapshot() {
        let service = ModelCatalogService(userDefaults: userDefaults)

        XCTAssertFalse(service.cachedModelIDs(for: "openai")?.isEmpty ?? true)
        XCTAssertFalse(service.cachedModelIDs(for: "anthropic")?.isEmpty ?? true)
        XCTAssertFalse(service.cachedModelIDs(for: "gemini")?.isEmpty ?? true)
    }

    private static let fixtureData = Data(
        """
        {
          "openai": {
            "models": {
              "text-embedding-3-large": {
                "id": "text-embedding-3-large",
                "last_updated": "2026-05-01",
                "modalities": { "input": ["text"], "output": ["embedding"] }
              },
              "gpt-4.1-mini": {
                "id": "gpt-4.1-mini",
                "last_updated": "2026-04-01",
                "modalities": { "input": ["text"], "output": ["text"] }
              },
              "gpt-5.2": {
                "id": "gpt-5.2",
                "last_updated": "2026-05-10",
                "modalities": { "input": ["text", "image"], "output": ["text"] }
              }
            }
          },
          "google": {
            "models": {
              "gemini-3.5-flash": {
                "id": "gemini-3.5-flash",
                "last_updated": "2026-05-19",
                "modalities": { "input": ["text"], "output": ["text"] }
              }
            }
          }
        }
        """.data(using: .utf8)!
    )

    private static let bundledFallbackData = Data(
        """
        {
          "fetchedAt": 821692800,
          "providerModels": {
            "openai": ["gpt-5.2"]
          }
        }
        """.data(using: .utf8)!
    )
}
