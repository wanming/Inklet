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
    func testWelcomeGuideWalksEveryStepAndFinishesOnTheLast() throws {
        let (settings, _) = try makeModel(keychain: ProviderSelectionKeychainClient())
        let guide = WelcomeGuideViewModel(settings: settings)
        var didFinish = false
        guide.onFinish = { didFinish = true }

        XCTAssertEqual(guide.step, .welcome)
        for _ in 1..<WelcomeGuideViewModel.Step.allCases.count {
            guide.performPrimaryAction()
        }
        XCTAssertEqual(guide.step, .ready)
        XCTAssertFalse(didFinish)

        guide.goBack()
        XCTAssertEqual(guide.step, .dictation)
        guide.performPrimaryAction()
        guide.performPrimaryAction()
        XCTAssertTrue(didFinish)
    }

    @MainActor
    func testWelcomeGuideCloudChoiceSavesTheOpenAIKey() throws {
        let keychain = ProviderSelectionKeychainClient()
        let (settings, configStore) = try makeModel(keychain: keychain)
        settings.selectProvider(LLMProviderPreset.builtIn.id)
        let guide = WelcomeGuideViewModel(settings: settings)
        guide.performPrimaryAction()
        guide.performPrimaryAction()
        XCTAssertEqual(guide.step, .writingModel)

        guide.selectWritingChoice(.builtIn)
        guide.selectWritingChoice(.cloud)
        settings.providerAPIKey = "sk-guide"
        guide.performPrimaryAction()

        XCTAssertEqual(guide.step, .dictation)
        XCTAssertEqual(try configStore.load().providerID, LLMProviderPreset.openAI.id)
        XCTAssertEqual(keychain.value(forAccount: LLMProviderPreset.openAI.id), "sk-guide")
    }

    @MainActor
    func testWelcomeGuideCloudCardCanPickAnyCloudProvider() throws {
        let keychain = ProviderSelectionKeychainClient()
        let (settings, configStore) = try makeModel(keychain: keychain)
        settings.selectProvider(LLMProviderPreset.builtIn.id)
        let guide = WelcomeGuideViewModel(settings: settings)
        while guide.step != .writingModel {
            guide.performPrimaryAction()
        }

        XCTAssertTrue(guide.cloudProviderOptions.contains { $0.id == "deepseek" })
        XCTAssertFalse(guide.cloudProviderOptions.contains { $0.runsLocally })
        guide.selectCloudProvider("deepseek")
        XCTAssertEqual(guide.writingChoice, .cloud)
        XCTAssertTrue(guide.needsCloudAPIKey)
        settings.providerAPIKey = "sk-deepseek"
        guide.performPrimaryAction()

        XCTAssertEqual(try configStore.load().providerID, "deepseek")
        XCTAssertEqual(keychain.value(forAccount: "deepseek"), "sk-deepseek")
        guide.goBack()
        guide.selectWritingChoice(.builtIn)
        guide.selectWritingChoice(.cloud)
        XCTAssertEqual(settings.config.providerID, "deepseek")
    }

    @MainActor
    func testWelcomeGuideSavesShortcutsOnTheModelAndDictationSteps() throws {
        let (settings, configStore) = try makeModel(keychain: ProviderSelectionKeychainClient())
        let guide = WelcomeGuideViewModel(settings: settings)
        while guide.step != .writingModel {
            guide.performPrimaryAction()
        }

        settings.config.hotkey = "⌘⇧K"
        guide.performPrimaryAction()
        XCTAssertEqual(guide.step, .dictation)
        XCTAssertEqual(try configStore.load().hotkey, "⌘⇧K")

        settings.config.voiceInput.shortcut = .leftCommand
        guide.performPrimaryAction()
        XCTAssertEqual(guide.step, .ready)
        XCTAssertEqual(try configStore.load().voiceInput.shortcut, .leftCommand)
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

final class LocalAPIKeyFileStoreTests: XCTestCase {
    private func makeStore(
        keychain: ProviderSelectionKeychainClient
    ) -> (LocalAPIKeyStore, APIKeyFileStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalAPIKeyFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let fileStore = APIKeyFileStore(fileURL: directory.appendingPathComponent(APIKeyFileStore.fileName))
        let store = LocalAPIKeyStore(fileStore: fileStore) { providerID in
            KeychainStore(service: "file-store-test", account: providerID, client: keychain)
        }
        return (store, fileStore)
    }

    func testKeychainKeyFromAnEarlierVersionIsCopiedToTheFileAndKeptInTheKeychain() {
        let keychain = ProviderSelectionKeychainClient(values: ["openai": "sk-old"])
        let (store, fileStore) = makeStore(keychain: keychain)

        XCTAssertEqual(store.loadAPIKey(forProviderID: "openai"), "sk-old")
        XCTAssertEqual(fileStore.loadAPIKey(forProviderID: "openai"), "sk-old")
        // An earlier version only reads the Keychain, so going back keeps the key.
        XCTAssertEqual(keychain.value(forAccount: "openai"), "sk-old")
    }

    func testFileKeyWinsOverADifferentKeychainKey() throws {
        let keychain = ProviderSelectionKeychainClient(values: ["openai": "sk-keychain"])
        let (store, fileStore) = makeStore(keychain: keychain)
        try fileStore.saveAPIKey("sk-file", forProviderID: "openai")

        XCTAssertEqual(store.loadAPIKey(forProviderID: "openai"), "sk-file")
    }

    func testNewUserHasNoKeyAndNoFile() {
        let (store, fileStore) = makeStore(keychain: ProviderSelectionKeychainClient())

        XCTAssertNil(store.loadAPIKey(forProviderID: "openai"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileStore.fileURL.path))
    }

    func testClearingAKeyAlsoRemovesTheKeychainCopySoItDoesNotComeBack() throws {
        let keychain = ProviderSelectionKeychainClient(values: ["openai": "sk-old"])
        let (store, _) = makeStore(keychain: keychain)
        XCTAssertEqual(store.loadAPIKey(forProviderID: "openai"), "sk-old")

        try store.saveAPIKey("", forProviderID: "openai")

        XCTAssertNil(keychain.value(forAccount: "openai"))
        XCTAssertEqual(store.loadAPIKey(forProviderID: "openai"), "")

        try store.deleteAPIKey(forProviderID: "openai")
        XCTAssertNil(store.loadAPIKey(forProviderID: "openai"))
    }

    func testKeyFileIsReadableOnlyByTheCurrentUser() throws {
        let (store, fileStore) = makeStore(keychain: ProviderSelectionKeychainClient())
        try store.saveAPIKey("sk-new", forProviderID: "deepseek")

        let attributes = try FileManager.default.attributesOfItem(atPath: fileStore.fileURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(store.loadAPIKey(forProviderID: "deepseek"), "sk-new")
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
