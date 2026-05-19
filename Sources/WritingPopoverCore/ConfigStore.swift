import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var providerID: String
    public var model: String
    public var temperature: Double
    public var timeoutSeconds: Double
    public var hotkey: String
    public var defaultModeID: String
    public var promptModes: [PromptMode]

    public init(
        version: Int = 1,
        providerID: String = LLMProviderPreset.openAI.id,
        model: String,
        temperature: Double,
        timeoutSeconds: Double,
        hotkey: String,
        defaultModeID: String,
        promptModes: [PromptMode]
    ) {
        self.version = version
        self.providerID = providerID
        self.model = model
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.hotkey = hotkey
        self.defaultModeID = defaultModeID
        self.promptModes = promptModes
    }

    public static func defaultConfig() -> AppConfig {
        AppConfig(
            providerID: LLMProviderPreset.openAI.id,
            model: "gpt-4.1-mini",
            temperature: 0.2,
            timeoutSeconds: 20,
            hotkey: "⌥Space",
            defaultModeID: PromptMode.autoID,
            promptModes: PromptModeStore.defaultStore().modes
        )
    }

    public var promptModeStore: PromptModeStore {
        PromptModeStore(modes: promptModes)
    }

    public var visiblePromptModes: [PromptMode] {
        promptModeStore.visibleModes
    }

    public func visibleModeID(preferredModeID: String) -> String {
        let visibleModeIDs = Set(visiblePromptModes.map(\.id))
        let fallbackIDs = [preferredModeID, defaultModeID, PromptMode.autoID]

        for modeID in fallbackIDs where visibleModeIDs.contains(modeID) {
            return modeID
        }

        return visiblePromptModes.first?.id ?? PromptMode.polishEnglishID
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case providerID
        case model
        case temperature
        case timeoutSeconds
        case hotkey
        case defaultModeID
        case promptModes
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
        defaultModeID = try container.decodeIfPresent(String.self, forKey: .defaultModeID) ?? defaults.defaultModeID
        promptModes = try container.decodeIfPresent([PromptMode].self, forKey: .promptModes) ?? defaults.promptModes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(version, forKey: .version)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(model, forKey: .model)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(defaultModeID, forKey: .defaultModeID)
        try container.encode(promptModes, forKey: .promptModes)
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
