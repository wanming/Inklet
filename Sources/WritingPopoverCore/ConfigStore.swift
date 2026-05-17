import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var model: String
    public var temperature: Double
    public var timeoutSeconds: Double
    public var hotkey: String
    public var defaultModeID: String
    public var promptModes: [PromptMode]

    public init(
        model: String,
        temperature: Double,
        timeoutSeconds: Double,
        hotkey: String,
        defaultModeID: String,
        promptModes: [PromptMode]
    ) {
        self.model = model
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.hotkey = hotkey
        self.defaultModeID = defaultModeID
        self.promptModes = promptModes
    }

    public static func defaultConfig() -> AppConfig {
        AppConfig(
            model: "gpt-4.1-mini",
            temperature: 0.2,
            timeoutSeconds: 20,
            hotkey: "⌥Space",
            defaultModeID: PromptMode.autoID,
            promptModes: PromptModeStore.defaultStore().modes
        )
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
