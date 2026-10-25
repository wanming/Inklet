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

        /// The keys people can pick; turning dictation off is a separate switch.
        public static var selectableCases: [Shortcut] {
            allCases.filter { $0 != .disabled }
        }
    }

    public var isEnabled: Bool
    public var shortcut: Shortcut
    public private(set) var speechEndpoint: String
    public var speechModel: String
    public var microphoneDeviceID: String?

    public init(
        shortcut: Shortcut,
        speechModel: String,
        microphoneDeviceID: String?,
        isEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled && shortcut != .disabled
        self.shortcut = shortcut == .disabled ? Self.defaultShortcut : shortcut
        self.speechEndpoint = Self.defaultSpeechEndpoint
        self.speechModel = speechModel
        self.microphoneDeviceID = microphoneDeviceID
    }

    public static let defaultShortcut: Shortcut = .rightOption

    /// The shortcut the dictation monitor listens for: `.disabled` while dictation is turned off.
    public var activeShortcut: Shortcut {
        isEnabled ? shortcut : .disabled
    }

    public static func defaultConfig() -> VoiceInputConfig {
        VoiceInputConfig(
            shortcut: defaultShortcut,
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
        let savedShortcut = try container.decodeIfPresent(Shortcut.self, forKey: .shortcut) ?? defaults.shortcut
        // Older versions turned dictation off by saving the `.disabled` shortcut.
        isEnabled = try (container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true) && savedShortcut != .disabled
        shortcut = savedShortcut == .disabled ? Self.defaultShortcut : savedShortcut
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
