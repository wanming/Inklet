import Foundation

public struct VoiceInputConfig: Codable, Equatable, Sendable {
    public static let defaultSpeechEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    public static let defaultSpeechModel = "gpt-4o-mini-transcribe"

    public enum Shortcut: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        case rightOption
        case rightCommand
        case leftOption
        case leftCommand
        case disabled

        public var id: String { rawValue }

        /// Turning dictation off is a separate switch, so Settings offers only real keys.
        public static let settingsCases: [Self] = [.rightOption, .rightCommand, .leftOption, .leftCommand]
    }

    /// Where speech is turned into text.
    public enum Engine: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        /// Qwen3-ASR on the built-in engine, on this Mac.
        case builtIn
        /// OpenAI realtime transcription, with the OpenAI API key.
        case openAI

        public var id: String { rawValue }
    }

    public var isEnabled: Bool
    public var engine: Engine
    public var shortcut: Shortcut
    public private(set) var speechEndpoint: String
    public var speechModel: String
    public var microphoneDeviceID: String?

    public init(
        isEnabled: Bool = true,
        engine: Engine = .builtIn,
        shortcut: Shortcut,
        speechModel: String,
        microphoneDeviceID: String?
    ) {
        self.isEnabled = isEnabled
        self.engine = engine
        self.shortcut = shortcut
        self.speechEndpoint = Self.defaultSpeechEndpoint
        self.speechModel = speechModel
        self.microphoneDeviceID = microphoneDeviceID
    }

    /// The shortcut dictation should listen for, or `.disabled` while dictation is turned off.
    public var activeShortcut: Shortcut {
        isEnabled ? shortcut : .disabled
    }

    /// The engine dictation runs on. Without the built-in engine (Intel Macs, or a build without
    /// llama-server), dictation uses OpenAI.
    public func resolvedEngine(isBuiltInEngineAvailable: Bool) -> Engine {
        isBuiltInEngineAvailable ? engine : .openAI
    }

    public static func defaultConfig() -> VoiceInputConfig {
        VoiceInputConfig(
            shortcut: .rightOption,
            speechModel: defaultSpeechModel,
            microphoneDeviceID: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case engine
        case shortcut
        case speechEndpoint
        case speechModel
        case microphoneDeviceID
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultConfig()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedShortcut = try container.decodeIfPresent(Shortcut.self, forKey: .shortcut) ?? defaults.shortcut
        // Older configs turned dictation off by choosing the Disabled shortcut.
        let decodedIsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isEnabled = decodedIsEnabled && decodedShortcut != .disabled
        // Configs saved before the built-in engine existed keep the OpenAI dictation they had.
        engine = try container.decodeIfPresent(Engine.self, forKey: .engine) ?? .openAI
        shortcut = decodedShortcut == .disabled ? defaults.shortcut : decodedShortcut
        _ = try container.decodeIfPresent(String.self, forKey: .speechEndpoint)
        speechEndpoint = Self.defaultSpeechEndpoint
        speechModel = try container.decodeIfPresent(String.self, forKey: .speechModel)
            ?? defaults.speechModel
        microphoneDeviceID = try container.decodeIfPresent(String.self, forKey: .microphoneDeviceID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(engine, forKey: .engine)
        try container.encode(shortcut, forKey: .shortcut)
        try container.encode(Self.defaultSpeechEndpoint, forKey: .speechEndpoint)
        try container.encode(speechModel, forKey: .speechModel)
        try container.encodeIfPresent(microphoneDeviceID, forKey: .microphoneDeviceID)
    }
}
