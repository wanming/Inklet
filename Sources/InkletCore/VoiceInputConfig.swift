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

    public var isEnabled: Bool
    public var shortcut: Shortcut
    public private(set) var speechEndpoint: String
    public var speechModel: String
    public var microphoneDeviceID: String?

    public init(
        isEnabled: Bool = true,
        shortcut: Shortcut,
        speechModel: String,
        microphoneDeviceID: String?
    ) {
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.speechEndpoint = Self.defaultSpeechEndpoint
        self.speechModel = speechModel
        self.microphoneDeviceID = microphoneDeviceID
    }

    /// The shortcut dictation should listen for, or `.disabled` while dictation is turned off.
    public var activeShortcut: Shortcut {
        isEnabled ? shortcut : .disabled
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
        try container.encode(shortcut, forKey: .shortcut)
        try container.encode(Self.defaultSpeechEndpoint, forKey: .speechEndpoint)
        try container.encode(speechModel, forKey: .speechModel)
        try container.encodeIfPresent(microphoneDeviceID, forKey: .microphoneDeviceID)
    }
}
