import Foundation

public enum AppAppearance: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var providerID: String
    public var model: String
    public var temperature: Double
    public var timeoutSeconds: Double
    public var hotkey: String
    public var appearance: AppAppearance
    public var defaultModeID: String
    public var promptModes: [PromptMode]
    public var customOpenAICompatibleEndpoint: String

    public init(
        version: Int = 1,
        providerID: String = LLMProviderPreset.openAI.id,
        model: String,
        temperature: Double,
        timeoutSeconds: Double,
        hotkey: String,
        appearance: AppAppearance = .system,
        defaultModeID: String,
        promptModes: [PromptMode],
        customOpenAICompatibleEndpoint: String = LLMProviderPreset.customOpenAICompatible.endpoint.absoluteString
    ) {
        self.version = version
        self.providerID = providerID
        self.model = model
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.hotkey = hotkey
        self.appearance = appearance
        self.defaultModeID = defaultModeID
        self.promptModes = promptModes
        self.customOpenAICompatibleEndpoint = customOpenAICompatibleEndpoint
    }

    public static func defaultConfig() -> AppConfig {
        AppConfig(
            providerID: LLMProviderPreset.openAI.id,
            model: LLMProviderPreset.openAI.defaultModel,
            temperature: 0.2,
            timeoutSeconds: 20,
            hotkey: "⌥Space",
            appearance: .system,
            defaultModeID: PromptMode.translateToEnglishID,
            promptModes: PromptModeStore.defaultStore().modes
        )
    }

    public var resolvedProviderPreset: LLMProviderPreset {
        var preset = LLMProviderPreset.preset(id: providerID)
        if providerID == LLMProviderPreset.customOpenAICompatible.id,
           let endpoint = URL(string: customOpenAICompatibleEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)) {
            preset.endpoint = endpoint
        }
        return preset
    }

    public var promptModeStore: PromptModeStore {
        PromptModeStore(modes: promptModes)
    }

    public var visiblePromptModes: [PromptMode] {
        promptModeStore.visibleModes
    }

    public func visibleModeID(preferredModeID: String) -> String {
        let visibleModeIDs = Set(visiblePromptModes.map(\.id))
        let fallbackIDs = [preferredModeID, defaultModeID]

        for modeID in fallbackIDs where visibleModeIDs.contains(modeID) {
            return modeID
        }

        return visiblePromptModes.first?.id ?? PromptMode.translateToEnglishID
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case providerID
        case model
        case temperature
        case timeoutSeconds
        case hotkey
        case appearance
        case defaultModeID
        case promptModes
        case customOpenAICompatibleEndpoint
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppConfig.defaultConfig()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? defaults.providerID
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? defaults.model
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? defaults.temperature
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? defaults.timeoutSeconds
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? defaults.hotkey
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? defaults.appearance
        let decodedDefaultModeID = try container.decodeIfPresent(String.self, forKey: .defaultModeID) ?? defaults.defaultModeID
        promptModes = AppConfig.migratedPromptModes(
            try container.decodeIfPresent([PromptMode].self, forKey: .promptModes) ?? defaults.promptModes
        )
        defaultModeID = AppConfig.legacyPromptModeIDs.contains(decodedDefaultModeID)
            ? defaults.defaultModeID
            : decodedDefaultModeID
        customOpenAICompatibleEndpoint = try container.decodeIfPresent(
            String.self,
            forKey: .customOpenAICompatibleEndpoint
        ) ?? defaults.customOpenAICompatibleEndpoint
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(version, forKey: .version)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(model, forKey: .model)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(defaultModeID, forKey: .defaultModeID)
        try container.encode(promptModes, forKey: .promptModes)
        try container.encode(customOpenAICompatibleEndpoint, forKey: .customOpenAICompatibleEndpoint)
    }

    private static func migratedPromptModes(_ modes: [PromptMode]) -> [PromptMode] {
        let legacyIDs = legacyPromptModeIDs
        guard modes.contains(where: { legacyIDs.contains($0.id) }) else {
            return modes
        }

        let modesWithoutLegacy = modes.filter { !legacyIDs.contains($0.id) }
        let existingIDs = Set(modesWithoutLegacy.map(\.id))
        let missingDefaults = PromptModeStore.defaultStore().modes.filter { !existingIDs.contains($0.id) }

        return (modesWithoutLegacy + missingDefaults)
            .enumerated()
            .map { index, mode in
                var migratedMode = mode
                migratedMode.participatesInAuto = false
                migratedMode.autoRule = .none
                migratedMode.sortOrder = index
                return migratedMode
            }
    }

    private static var legacyPromptModeIDs: Set<String> {
        [
            PromptMode.autoID,
            PromptMode.chineseToEnglishID,
            PromptMode.polishEnglishID
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
    public static let defaultKey = "appConfig"

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

public struct LocalAPIKeyStore: @unchecked Sendable {
    public static let defaultKeyPrefix = "providerAPIKey"

    private let userDefaults: UserDefaults
    private let keyPrefix: String

    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = LocalAPIKeyStore.defaultKeyPrefix
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    public func loadAPIKey(forProviderID providerID: String) -> String? {
        userDefaults.string(forKey: key(forProviderID: providerID))
    }

    public func saveAPIKey(_ apiKey: String, forProviderID providerID: String) {
        userDefaults.set(apiKey, forKey: key(forProviderID: providerID))
    }

    public func deleteAPIKey(forProviderID providerID: String) {
        userDefaults.removeObject(forKey: key(forProviderID: providerID))
    }

    private func key(forProviderID providerID: String) -> String {
        "\(keyPrefix).\(providerID)"
    }
}
