import XCTest
import Security
@testable import InkletCore

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

    private func mode(id: String, sortOrder: Int, isVisible: Bool = true) -> PromptMode {
        PromptMode(
            id: id,
            name: id,
            description: "\(id) description",
            systemPrompt: "\(id) prompt",
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: sortOrder,
            isVisible: isVisible
        )
    }

    func testDefaultConfigMatchesSpec() {
        let config = AppConfig.defaultConfig()

        XCTAssertEqual(config.providerID, LLMProviderPreset.openAI.id)
        XCTAssertEqual(config.model, LLMProviderPreset.openAI.defaultModel)
        XCTAssertEqual(config.temperature, 0.2)
        XCTAssertEqual(config.timeoutSeconds, 20)
        XCTAssertEqual(config.hotkey, "⌥Space")
        XCTAssertEqual(config.appearance, .system)
        XCTAssertEqual(config.defaultVisibleModeID, PromptMode.translateToEnglishID)
        XCTAssertEqual(
            config.customOpenAICompatibleEndpoint,
            LLMProviderPreset.customOpenAICompatible.endpoint.absoluteString
        )
    }

    func testConfigRoundTripsThroughUserDefaults() throws {
        let suiteName = "ConfigStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsConfigStore(userDefaults: userDefaults)
        var config = AppConfig.defaultConfig()
        config.providerID = "anthropic"
        config.model = "test-model"
        config.temperature = 0.7
        config.timeoutSeconds = 9
        config.hotkey = "⌘Space"
        config.appearance = .dark
        config.customOpenAICompatibleEndpoint = "http://127.0.0.1:1234/v1/chat/completions"
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
        XCTAssertEqual(config.providerID, AppConfig.defaultConfig().providerID)
        XCTAssertEqual(config.temperature, AppConfig.defaultConfig().temperature)
        XCTAssertEqual(config.timeoutSeconds, AppConfig.defaultConfig().timeoutSeconds)
        XCTAssertEqual(config.hotkey, AppConfig.defaultConfig().hotkey)
        XCTAssertEqual(config.appearance, AppConfig.defaultConfig().appearance)
        XCTAssertEqual(config.defaultVisibleModeID, AppConfig.defaultConfig().defaultVisibleModeID)
        XCTAssertEqual(config.promptModes, AppConfig.defaultConfig().promptModes)
        XCTAssertEqual(
            config.customOpenAICompatibleEndpoint,
            AppConfig.defaultConfig().customOpenAICompatibleEndpoint
        )
    }

    func testConfigDecodeMigratesLegacyModesToFocusedDefaults() throws {
        let data = """
        {
            "promptModes": [
                {
                    "id": "\(PromptMode.autoID)",
                    "name": "Auto",
                    "description": "Auto",
                    "systemPrompt": "",
                    "shortcut": null,
                    "participatesInAuto": false,
                    "autoRule": "none",
                    "sortOrder": 0,
                    "isVisible": true
                },
                {
                    "id": "\(PromptMode.chineseToEnglishID)",
                    "name": "Chinese to English",
                    "description": "Translate Chinese",
                    "systemPrompt": "Translate Chinese.",
                    "shortcut": "⌘1",
                    "participatesInAuto": true,
                    "autoRule": "chineseHeavy",
                    "sortOrder": 1,
                    "isVisible": true
                },
                {
                    "id": "\(PromptMode.improveWritingID)",
                    "name": "Improve Writing",
                    "description": "Improve",
                    "systemPrompt": "Improve writing.",
                    "shortcut": "⌘2",
                    "participatesInAuto": false,
                    "autoRule": "none",
                    "sortOrder": 2,
                    "isVisible": true
                },
                {
                    "id": "custom-saved",
                    "name": "Saved Custom",
                    "description": "Saved custom mode",
                    "systemPrompt": "Saved custom prompt",
                    "shortcut": null,
                    "participatesInAuto": true,
                    "autoRule": "englishHeavy",
                    "sortOrder": 3,
                    "isVisible": true
                }
            ]
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(config.defaultVisibleModeID, PromptMode.translateToEnglishID)
        XCTAssertFalse(config.promptModes.contains { $0.id == PromptMode.autoID })
        XCTAssertFalse(config.promptModes.contains { $0.id == PromptMode.chineseToEnglishID })
        XCTAssertFalse(config.promptModes.contains { $0.id == PromptMode.improveWritingID })
        XCTAssertTrue(config.promptModes.contains { $0.id == "custom-saved" })
        XCTAssertEqual(
            config.promptModes.prefix(2).map(\.id),
            [PromptMode.translateToEnglishID, PromptMode.chineseSummaryID]
        )
        XCTAssertTrue(config.promptModes.allSatisfy { !$0.participatesInAuto && $0.autoRule == .none })
    }

    func testResolvedProviderPresetUsesCustomOpenAICompatibleEndpoint() {
        var config = AppConfig.defaultConfig()
        config.providerID = LLMProviderPreset.customOpenAICompatible.id
        config.customOpenAICompatibleEndpoint = "http://127.0.0.1:1234/v1/chat/completions"

        XCTAssertEqual(
            config.resolvedProviderPreset.endpoint.absoluteString,
            "http://127.0.0.1:1234/v1/chat/completions"
        )
    }

    func testVisibleModeIDKeepsVisiblePreferredMode() {
        var config = AppConfig.defaultConfig()
        config.promptModes = [
            mode(id: PromptMode.autoID, sortOrder: 0),
            mode(id: "preferred", sortOrder: 1),
            mode(id: "fallback", sortOrder: 2)
        ]

        XCTAssertEqual(config.visibleModeID(preferredModeID: "preferred"), "preferred")
    }

    func testVisibleModeIDFallsBackToFirstVisibleMode() {
        var config = AppConfig.defaultConfig()
        config.promptModes = [
            mode(id: "first-visible", sortOrder: 0),
            mode(id: "hidden-preferred", sortOrder: 1, isVisible: false),
            mode(id: "fallback", sortOrder: 2)
        ]

        XCTAssertEqual(config.visibleModeID(preferredModeID: "hidden-preferred"), "first-visible")
    }

    func testDefaultVisibleModeIDUsesFirstVisibleMode() {
        var config = AppConfig.defaultConfig()
        config.promptModes = [
            mode(id: "hidden-first", sortOrder: 0, isVisible: false),
            mode(id: "first-visible", sortOrder: 0),
            mode(id: "second-visible", sortOrder: 1),
        ]

        XCTAssertEqual(config.defaultVisibleModeID, "first-visible")
        XCTAssertEqual(config.visibleModeID(preferredModeID: "missing"), "first-visible")
    }

    func testVisiblePromptModesUsesConfiguredPromptModes() {
        var config = AppConfig.defaultConfig()
        config.promptModes = [
            mode(id: "later", sortOrder: 2),
            mode(id: "hidden", sortOrder: 0, isVisible: false),
            mode(id: "earlier", sortOrder: 1)
        ]

        XCTAssertEqual(config.visiblePromptModes.map(\.id), ["earlier", "later"])
    }

    func testLocalAPIKeyStoreRoundTripsAndDeletesProviderKey() throws {
        let suiteName = "LocalAPIKeyStoreTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = LocalAPIKeyStore(userDefaults: userDefaults, keyPrefix: "testAPIKey")

        store.saveAPIKey("local-key", forProviderID: "openai")

        XCTAssertEqual(store.loadAPIKey(forProviderID: "openai"), "local-key")
        XCTAssertNil(store.loadAPIKey(forProviderID: "anthropic"))

        store.deleteAPIKey(forProviderID: "openai")

        XCTAssertNil(store.loadAPIKey(forProviderID: "openai"))
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
