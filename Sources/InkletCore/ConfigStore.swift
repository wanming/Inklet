import Foundation

public enum AppAppearance: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public static let currentVersion = 5

    private static let lunaDefaultMigrationVersion = 3
    private static let providerSelectionVersion = 5
    private static let formerOpenAIDefaultModel = "gpt-5.4-mini"

    public var version: Int
    public var providerID: String
    public var model: String
    public var timeoutSeconds: Double
    public var hotkey: String
    public var appearance: AppAppearance
    public var promptModes: [PromptMode]
    public var customOpenAICompatibleEndpoint: String
    public var voiceInput: VoiceInputConfig
    public var selectionActions: SelectionActionsConfig

    public init(
        version: Int = AppConfig.currentVersion,
        providerID: String = LLMProviderPreset.openAI.id,
        model: String,
        timeoutSeconds: Double,
        hotkey: String,
        appearance: AppAppearance = .system,
        promptModes: [PromptMode],
        customOpenAICompatibleEndpoint: String = LLMProviderPreset.customOpenAICompatible.endpoint.absoluteString,
        voiceInput: VoiceInputConfig = VoiceInputConfig.defaultConfig(),
        selectionActions: SelectionActionsConfig = SelectionActionsConfig.defaultConfig()
    ) {
        self.version = version
        self.providerID = providerID
        self.model = model
        self.timeoutSeconds = timeoutSeconds
        self.hotkey = hotkey
        self.appearance = appearance
        self.promptModes = promptModes
        self.customOpenAICompatibleEndpoint = customOpenAICompatibleEndpoint
        self.voiceInput = voiceInput
        self.selectionActions = selectionActions
    }

    public static func defaultConfig() -> AppConfig {
        AppConfig(
            providerID: LLMProviderPreset.openAI.id,
            model: LLMProviderPreset.openAI.defaultModel,
            timeoutSeconds: 20,
            hotkey: "⌥Space",
            appearance: .system,
            promptModes: PromptModeStore.defaultStore().modes
        )
    }

    public var resolvedProviderPreset: LLMProviderPreset {
        var preset = LLMProviderPreset.preset(id: providerID)
        if preset.id == LLMProviderPreset.customOpenAICompatible.id,
           let endpoint = URL(string: customOpenAICompatibleEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = endpoint.scheme?.lowercased(),
           scheme == "https" || scheme == "http",
           endpoint.host != nil {
            preset.endpoint = endpoint
        }
        return preset
    }

    /// Local models may first have to load into memory, so they get at least two minutes.
    public static let localModelMinimumTimeoutSeconds: Double = 120

    public var effectiveTimeoutSeconds: Double {
        resolvedProviderPreset.runsLocally
            ? max(timeoutSeconds, AppConfig.localModelMinimumTimeoutSeconds)
            : timeoutSeconds
    }

    public var promptModeStore: PromptModeStore {
        PromptModeStore(modes: promptModes)
    }

    public var visiblePromptModes: [PromptMode] {
        promptModeStore.visibleModes
    }

    public var defaultVisibleModeID: String {
        visiblePromptModes.first?.id ?? PromptMode.translateToEnglishID
    }

    public func visibleModeID(preferredModeID: String) -> String {
        let visibleModeIDs = Set(visiblePromptModes.map(\.id))
        if visibleModeIDs.contains(preferredModeID) {
            return preferredModeID
        }

        return defaultVisibleModeID
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case providerID
        case model
        case timeoutSeconds
        case hotkey
        case appearance
        case promptModes
        case customOpenAICompatibleEndpoint
        case voiceInput
        case selectionActions
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppConfig.defaultConfig()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        version = max(decodedVersion, AppConfig.currentVersion)
        let decodedProviderID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? defaults.providerID
        // Configurations saved before provider selection always wrote with OpenAI.
        let resolvedProviderID = decodedVersion >= AppConfig.providerSelectionVersion
            && LLMProviderPreset.all.contains(where: { $0.id == decodedProviderID })
            ? decodedProviderID
            : LLMProviderPreset.openAI.id
        providerID = resolvedProviderID
        if resolvedProviderID == decodedProviderID {
            let decodedModel = try container.decodeIfPresent(String.self, forKey: .model)
                ?? LLMProviderPreset.preset(id: resolvedProviderID).defaultModel
            if resolvedProviderID == LLMProviderPreset.openAI.id,
               decodedVersion < AppConfig.lunaDefaultMigrationVersion,
               decodedModel == AppConfig.formerOpenAIDefaultModel {
                model = defaults.model
            } else {
                model = decodedModel
            }
        } else {
            model = defaults.model
        }
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? defaults.timeoutSeconds
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? defaults.hotkey
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? defaults.appearance
        promptModes = AppConfig.migratedPromptModes(
            try container.decodeIfPresent([PromptMode].self, forKey: .promptModes) ?? defaults.promptModes
        )
        customOpenAICompatibleEndpoint = try container.decodeIfPresent(
            String.self,
            forKey: .customOpenAICompatibleEndpoint
        ) ?? defaults.customOpenAICompatibleEndpoint
        voiceInput = try container.decodeIfPresent(
            VoiceInputConfig.self,
            forKey: .voiceInput
        ) ?? defaults.voiceInput
        selectionActions = try container.decodeIfPresent(
            SelectionActionsConfig.self,
            forKey: .selectionActions
        ) ?? defaults.selectionActions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(version, forKey: .version)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(model, forKey: .model)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(promptModes, forKey: .promptModes)
        try container.encode(customOpenAICompatibleEndpoint, forKey: .customOpenAICompatibleEndpoint)
        try container.encode(voiceInput, forKey: .voiceInput)
        try container.encode(selectionActions, forKey: .selectionActions)
    }

    private static func migratedPromptModes(_ modes: [PromptMode]) -> [PromptMode] {
        let defaultModes = PromptModeStore.defaultStore().modes
        let defaultIDs = Set(defaultModes.map(\.id))
        let retiredIDs = retiredBuiltInPromptModeIDs
        let shouldMigrateBuiltIns = modes.contains { retiredIDs.contains($0.id) }
        let hasCurrentBuiltIns = modes.contains { defaultIDs.contains($0.id) }

        guard shouldMigrateBuiltIns || hasCurrentBuiltIns else {
            return modes
        }

        let migratedModes: [PromptMode]
        if shouldMigrateBuiltIns {
            let customModes = modes.filter { mode in
                !retiredIDs.contains(mode.id) && !defaultIDs.contains(mode.id)
            }
            migratedModes = defaultModes + customModes
        } else {
            let existingIDs = Set(modes.map(\.id))
            let missingDefaultModes = hasCurrentBuiltIns ? defaultModes.filter { !existingIDs.contains($0.id) } : []
            migratedModes = modes + missingDefaultModes
        }

        return migratedModes
            .enumerated()
            .map { index, mode in
                var migratedMode = mode
                if migratedMode.id == PromptMode.voiceCleanupID,
                   migratedMode.systemPrompt == legacyVoiceCleanupSystemPrompt,
                   let defaultVoiceCleanupMode = defaultModes.first(where: { $0.id == PromptMode.voiceCleanupID }) {
                    migratedMode.systemPrompt = defaultVoiceCleanupMode.systemPrompt
                }
                if migratedMode.id == PromptMode.summaryID,
                   migratedMode.name == legacyChineseSummaryName,
                   migratedMode.systemPrompt == legacyChineseSummarySystemPrompt,
                   let defaultSummaryMode = defaultModes.first(where: { $0.id == PromptMode.summaryID }) {
                    migratedMode.name = defaultSummaryMode.name
                    migratedMode.systemPrompt = defaultSummaryMode.systemPrompt
                }
                migratedMode.participatesInAuto = false
                migratedMode.autoRule = .none
                migratedMode.sortOrder = index
                return migratedMode
            }
    }

    private static var legacyVoiceCleanupSystemPrompt: String {
        """
        Rewrite raw speech transcription into text that is ready to insert.
        Preserve the user's intended meaning, language, names, numbers, code terms, and domain terms.
        Do not translate.
        Remove filler words, hesitation sounds, throat-clearing phrases, rambling setup, repeated words, repeated sentences, false starts, and abandoned fragments.
        When the user corrects themselves or gives multiple versions, keep the final intended version.
        Make the result concise, natural, and coherent, but do not add facts, examples, or intent that was not spoken.
        Keep useful details even if the original speech was messy.
        Fix punctuation, capitalization, and minor grammar issues.
        If there is no meaningful content, return an empty string.
        Return only the final cleaned text.
        """
    }

    private static let legacyChineseSummaryName = "To Chinese Summary"

    private static var legacyChineseSummarySystemPrompt: String {
        """
        Summarize the user's text in concise, natural Simplified Chinese.
        Capture the key facts, decisions, dates, names, numbers, and action items.
        Remove repetition and minor details unless they are important.
        Use clear paragraphs or short bullet points when that improves readability.
        Do not add information that is not in the original text.
        Do not include explanations about the task.
        Return only the Chinese summary.
        """
    }

    private static var retiredBuiltInPromptModeIDs: Set<String> {
        [
            PromptMode.autoID,
            PromptMode.chineseToEnglishID,
            PromptMode.polishEnglishID,
            PromptMode.improveWritingID,
            PromptMode.makeConciseID,
            PromptMode.professionalToneID,
            PromptMode.friendlyReplyID,
            PromptMode.customPromptID
        ]
    }
}

public enum ConfigStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
}

public protocol ConfigStore {
    func load() throws -> AppConfig
    func save(_ config: AppConfig) throws
}

public struct UserDefaultsConfigStore: ConfigStore {
    public static let defaultKey = InkletPreferenceKeys.appConfig

    private let userDefaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = UserDefaultsConfigStore.defaultKey,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.encoder = encoder
        self.decoder = decoder
    }

    public var hasSavedConfig: Bool {
        userDefaults.data(forKey: key) != nil
    }

    public func load() throws -> AppConfig {
        guard let data = userDefaults.data(forKey: key) else {
            return AppConfig.defaultConfig()
        }

        do {
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            throw ConfigStoreError.decodingFailed
        }
    }

    public func save(_ config: AppConfig) throws {
        do {
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: key)
        } catch {
            throw ConfigStoreError.encodingFailed
        }
    }
}

/// Provider API keys in a JSON file in Inklet's Application Support folder that only the current user
/// can read. Unlike the Keychain, it survives re-signing and reinstalling, and a reset only has to
/// delete the file.
public struct APIKeyFileStore: Sendable {
    public static let fileName = "api-keys.json"
    private static let lock = NSLock()

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func current() -> APIKeyFileStore {
        APIKeyFileStore(
            fileURL: InkletStoragePaths.currentOrLocalDevelopment().applicationSupportRootURL
                .appendingPathComponent(fileName)
        )
    }

    public func loadAPIKey(forProviderID providerID: String) -> String? {
        Self.lock.withLock { readKeys()[providerID] }
    }

    public func saveAPIKey(_ apiKey: String, forProviderID providerID: String) throws {
        try Self.lock.withLock {
            var keys = readKeys()
            keys[providerID] = apiKey
            try write(keys)
        }
    }

    public func deleteAPIKey(forProviderID providerID: String) throws {
        try Self.lock.withLock {
            var keys = readKeys()
            guard keys.removeValue(forKey: providerID) != nil else { return }
            try write(keys)
        }
    }

    private func readKeys() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let keys = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return keys
    }

    private func write(_ keys: [String: String]) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(keys).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        // Keep plaintext keys out of Time Machine backups.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var backupURL = fileURL
        try? backupURL.setResourceValues(resourceValues)
    }
}

public struct LocalAPIKeyStore: Sendable {
    public static let defaultKeychainService = "Inklet.ProviderAPIKey"
    public static let localBundleIdentifier = InkletStoragePaths.localBundleIdentifier
    public static let localKeychainService = "Inklet.Local.ProviderAPIKey"
    public static let defaultKeychainStore: @Sendable (String) -> KeychainStore = { providerID in
        KeychainStore(service: LocalAPIKeyStore.resolvedKeychainService(), account: providerID)
    }

    private let fileStore: APIKeyFileStore?
    private let keychainStore: @Sendable (String) -> KeychainStore

    /// Keys live in a file. A key that an earlier version saved in the Keychain is copied to the file the
    /// first time it is read.
    public init(fileStore: APIKeyFileStore = .current()) {
        self.init(fileStore: fileStore, legacyKeychainStore: LocalAPIKeyStore.defaultKeychainStore)
    }

    /// Keeps keys in the Keychain only.
    public init(keychainStore: @escaping @Sendable (String) -> KeychainStore) {
        self.init(fileStore: nil, legacyKeychainStore: keychainStore)
    }

    public init(
        fileStore: APIKeyFileStore?,
        legacyKeychainStore: @escaping @Sendable (String) -> KeychainStore
    ) {
        self.fileStore = fileStore
        self.keychainStore = legacyKeychainStore
    }

    public static func resolvedKeychainService(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> String {
        bundleIdentifier == localBundleIdentifier ? localKeychainService : defaultKeychainService
    }

    public func loadAPIKey(forProviderID providerID: String) -> String? {
        guard let fileStore else {
            return try? keychainStore(providerID).loadAPIKey()
        }
        if let apiKey = fileStore.loadAPIKey(forProviderID: providerID) {
            return apiKey
        }
        return moveKeychainKey(forProviderID: providerID, to: fileStore)
    }

    public func saveAPIKey(_ apiKey: String, forProviderID providerID: String) throws {
        guard let fileStore else {
            try keychainStore(providerID).saveAPIKey(apiKey)
            return
        }
        try fileStore.saveAPIKey(apiKey, forProviderID: providerID)
        // A key left in the Keychain would come back after this one is cleared.
        try? keychainStore(providerID).deleteAPIKey()
    }

    public func deleteAPIKey(forProviderID providerID: String) throws {
        guard let fileStore else {
            try keychainStore(providerID).deleteAPIKey()
            return
        }
        try fileStore.deleteAPIKey(forProviderID: providerID)
        try? keychainStore(providerID).deleteAPIKey()
    }

    /// Copies a key an earlier version saved in the Keychain into the file. The Keychain copy stays
    /// until the key is changed, so going back to an earlier version keeps working. Keys imported from
    /// the sandboxed version also land in the Keychain, so this runs whenever the file has no key for a
    /// provider, not only once.
    private func moveKeychainKey(forProviderID providerID: String, to fileStore: APIKeyFileStore) -> String? {
        guard let apiKey = try? keychainStore(providerID).loadAPIKey(), !apiKey.isEmpty else {
            return nil
        }
        try? fileStore.saveAPIKey(apiKey, forProviderID: providerID)
        return apiKey
    }
}
