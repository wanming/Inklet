import XCTest
import Security
@testable import WritingPopoverCore

final class ConfigStoreTests: XCTestCase {
    private final class FakeKeychainClient: KeychainClient {
        enum Call: Equatable {
            case copyMatching
            case update
            case add
        }

        var calls: [Call] = []
        var copyMatchingStatus: OSStatus = errSecItemNotFound
        var updateStatus: OSStatus = errSecItemNotFound
        var addStatus: OSStatus = errSecSuccess
        var copyMatchingResult: CFTypeRef?

        func copyMatching(_ query: [String: Any], result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            calls.append(.copyMatching)
            result?.pointee = copyMatchingResult
            return copyMatchingStatus
        }

        func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
            calls.append(.update)
            return updateStatus
        }

        func add(_ query: [String: Any], result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            calls.append(.add)
            return addStatus
        }
    }

    func testDefaultConfigMatchesSpec() {
        let config = AppConfig.defaultConfig()

        XCTAssertEqual(config.model, "gpt-4.1-mini")
        XCTAssertEqual(config.temperature, 0.2)
        XCTAssertEqual(config.timeoutSeconds, 20)
        XCTAssertEqual(config.hotkey, "⌥Space")
        XCTAssertEqual(config.defaultModeID, PromptMode.autoID)
    }

    func testConfigRoundTripsThroughUserDefaults() throws {
        let suiteName = "ConfigStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsConfigStore(userDefaults: userDefaults)
        var config = AppConfig.defaultConfig()
        config.model = "test-model"
        config.temperature = 0.7
        config.timeoutSeconds = 9
        config.hotkey = "⌘Space"
        config.defaultModeID = PromptMode.polishEnglishID
        config.promptModes = [
            PromptMode(
                id: "custom-test-mode",
                name: "Custom Test Mode",
                description: "Custom test description",
                systemPrompt: "Custom test prompt",
                shortcut: "⌘9",
                participatesInAuto: true,
                autoRule: .englishHeavy,
                sortOrder: 99,
                isVisible: false
            )
        ]

        try store.save(config)
        let loadedConfig = try store.load()

        XCTAssertEqual(loadedConfig, config)
    }

    func testConfigDecodeFallsBackToDefaultsForMissingFields() throws {
        let data = #"{"model":"saved-model"}"#.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(config.model, "saved-model")
        XCTAssertEqual(config.temperature, AppConfig.defaultConfig().temperature)
        XCTAssertEqual(config.timeoutSeconds, AppConfig.defaultConfig().timeoutSeconds)
        XCTAssertEqual(config.hotkey, AppConfig.defaultConfig().hotkey)
        XCTAssertEqual(config.defaultModeID, AppConfig.defaultConfig().defaultModeID)
        XCTAssertEqual(config.promptModes, AppConfig.defaultConfig().promptModes)
    }

    func testSaveAPIKeyUpdatesExistingKeyWithoutAdding() throws {
        let client = FakeKeychainClient()
        client.updateStatus = errSecSuccess
        let store = KeychainStore(client: client)

        try store.saveAPIKey("updated-key")

        XCTAssertEqual(client.calls, [.update])
    }

    func testSaveAPIKeyAddsWhenItemNotFound() throws {
        let client = FakeKeychainClient()
        client.updateStatus = errSecItemNotFound
        client.addStatus = errSecSuccess
        let store = KeychainStore(client: client)

        try store.saveAPIKey("new-key")

        XCTAssertEqual(client.calls, [.update, .add])
    }

    func testLoadAPIKeyReturnsNilWhenItemNotFound() throws {
        let client = FakeKeychainClient()
        client.copyMatchingStatus = errSecItemNotFound
        let store = KeychainStore(client: client)

        let apiKey = try store.loadAPIKey()

        XCTAssertNil(apiKey)
        XCTAssertEqual(client.calls, [.copyMatching])
    }

    func testLoadAPIKeyThrowsInvalidData() {
        let client = FakeKeychainClient()
        client.copyMatchingStatus = errSecSuccess
        client.copyMatchingResult = Data([0xFF]) as CFData
        let store = KeychainStore(client: client)

        XCTAssertThrowsError(try store.loadAPIKey()) { error in
            XCTAssertEqual(error as? KeychainStoreError, .invalidData)
        }
    }
}
