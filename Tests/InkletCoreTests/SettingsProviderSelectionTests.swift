import XCTest
import Security
@testable import Inklet
@testable import InkletCore

final class SettingsProviderSelectionTests: XCTestCase {
    @MainActor
    func testSwitchingProviderLoadsItsKeyAndDefaultModel() throws {
        let keychain = ProviderSelectionKeychainClient(values: [
            "openai": "sk-openai",
            "deepseek": "sk-deepseek"
        ])
        let (model, configStore) = try makeModel(keychain: keychain)

        XCTAssertTrue(model.usesOpenAIForWriting)
        XCTAssertEqual(model.providerAPIKey, "sk-openai")

        model.selectProvider("deepseek")

        XCTAssertFalse(model.usesOpenAIForWriting)
        XCTAssertEqual(model.config.providerID, "deepseek")
        XCTAssertEqual(model.config.model, LLMProviderPreset.preset(id: "deepseek").defaultModel)
        XCTAssertEqual(model.providerAPIKey, "sk-deepseek")
        XCTAssertEqual(model.openAIAPIKey, "sk-openai")
        XCTAssertEqual(try configStore.load().resolvedProviderPreset.id, "deepseek")
    }

    @MainActor
    func testWritingAndVoiceKeysSaveToTheirOwnProviders() throws {
        let keychain = ProviderSelectionKeychainClient()
        let (model, _) = try makeModel(keychain: keychain)

        model.selectProvider("anthropic")
        model.providerAPIKey = " sk-ant "
        model.openAIAPIKey = " sk-openai "

        XCTAssertTrue(model.flushPendingEdits())
        XCTAssertEqual(keychain.value(forAccount: "anthropic"), "sk-ant")
        XCTAssertEqual(keychain.value(forAccount: "openai"), "sk-openai")
    }

    @MainActor
    func testSwitchingProviderKeepsKeyTypedForPreviousProvider() throws {
        let keychain = ProviderSelectionKeychainClient()
        let (model, _) = try makeModel(keychain: keychain)

        model.providerAPIKey = "sk-openai"
        model.selectProvider("gemini")

        XCTAssertEqual(keychain.value(forAccount: "openai"), "sk-openai")
        XCTAssertEqual(model.openAIAPIKey, "sk-openai")
        XCTAssertEqual(model.providerAPIKey, "")

        model.selectProvider(LLMProviderPreset.openAI.id)

        XCTAssertTrue(model.usesOpenAIForWriting)
        XCTAssertEqual(model.providerAPIKey, "sk-openai")
        XCTAssertEqual(model.config.model, LLMProviderPreset.openAI.defaultModel)
    }

    @MainActor
    private func makeModel(
        keychain: ProviderSelectionKeychainClient
    ) throws -> (SettingsViewModel, UserDefaultsConfigStore) {
        let suiteName = "SettingsProviderSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let historyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsProviderSelection-\(UUID().uuidString).jsonl")
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: historyURL)
        }

        let configStore = UserDefaultsConfigStore(userDefaults: defaults)
        let model = SettingsViewModel(
            configStore: configStore,
            apiKeyStore: LocalAPIKeyStore { providerID in
                KeychainStore(service: "provider-selection-test", account: providerID, client: keychain)
            },
            modelCatalogService: ModelCatalogService(
                userDefaults: defaults,
                bundledFallbackData: { nil }
            ),
            historyStore: JSONLHistoryStore(fileURL: historyURL)
        )
        return (model, configStore)
    }
}

private final class ProviderSelectionKeychainClient: KeychainClient, @unchecked Sendable {
    private var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func value(forAccount account: String) -> String? {
        values[account]
    }

    func copyMatching(_ query: [String: Any], result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let account = query[kSecAttrAccount as String] as? String,
              let value = values[account]
        else {
            return errSecItemNotFound
        }
        result?.pointee = Data(value.utf8) as CFData
        return errSecSuccess
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        guard let account = query[kSecAttrAccount as String] as? String,
              values[account] != nil,
              let data = attributes[kSecValueData as String] as? Data
        else {
            return errSecItemNotFound
        }
        values[account] = String(decoding: data, as: UTF8.self)
        return errSecSuccess
    }

    func add(_ query: [String: Any], result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let account = query[kSecAttrAccount as String] as? String,
              let data = query[kSecValueData as String] as? Data
        else {
            return errSecParam
        }
        guard values[account] == nil else { return errSecDuplicateItem }
        values[account] = String(decoding: data, as: UTF8.self)
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        guard let account = query[kSecAttrAccount as String] as? String,
              values.removeValue(forKey: account) != nil
        else {
            return errSecItemNotFound
        }
        return errSecSuccess
    }
}
