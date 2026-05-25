import Foundation

public struct VoiceInputConfig: Codable, Equatable, Sendable {
    public static let openAISpeechProviderID = "openai-speech"
    public static let defaultSpeechEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    public static let defaultSpeechModel = "gpt-4o-mini-transcribe"

    public enum Shortcut: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        case rightOption
        case rightCommand
        case leftOption
        case leftCommand
        case disabled

        public var id: String { rawValue }
    }

    public var shortcut: Shortcut
    public var speechProviderID: String
    public var speechEndpoint: String
    public var speechModel: String
    public var autoProcessTranscription: Bool
    public var voiceCleanupPromptModeID: String

    public init(
        shortcut: Shortcut,
        speechProviderID: String,
        speechEndpoint: String,
        speechModel: String,
        autoProcessTranscription: Bool,
        voiceCleanupPromptModeID: String
    ) {
        self.shortcut = shortcut
        self.speechProviderID = speechProviderID
        self.speechEndpoint = speechEndpoint
        self.speechModel = speechModel
        self.autoProcessTranscription = autoProcessTranscription
        self.voiceCleanupPromptModeID = voiceCleanupPromptModeID
    }

    public static func defaultConfig() -> VoiceInputConfig {
        VoiceInputConfig(
            shortcut: .rightOption,
            speechProviderID: openAISpeechProviderID,
            speechEndpoint: defaultSpeechEndpoint,
            speechModel: defaultSpeechModel,
            autoProcessTranscription: true,
            voiceCleanupPromptModeID: PromptMode.voiceCleanupID
        )
    }
}
