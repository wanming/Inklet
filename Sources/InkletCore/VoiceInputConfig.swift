import Foundation

public struct VoiceInputConfig: Codable, Equatable, Sendable {
    public static let openAISpeechProviderID = LLMProviderPreset.openAI.id
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

    public enum SpeechProfile: String, Equatable, Sendable, CaseIterable, Identifiable {
        case openAIBalanced
        case openAIAccuracy
        case openAIWhisper
        case custom

        public var id: String { rawValue }

        public var endpoint: String? {
            switch self {
            case .openAIBalanced, .openAIAccuracy, .openAIWhisper:
                VoiceInputConfig.defaultSpeechEndpoint
            case .custom:
                nil
            }
        }

        public var model: String? {
            switch self {
            case .openAIBalanced:
                VoiceInputConfig.defaultSpeechModel
            case .openAIAccuracy:
                "gpt-4o-transcribe"
            case .openAIWhisper:
                "whisper-1"
            case .custom:
                nil
            }
        }

        public static func matching(endpoint: String, model: String) -> SpeechProfile {
            let normalizedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            return allCases.first { profile in
                guard let profileEndpoint = profile.endpoint, let profileModel = profile.model else {
                    return false
                }
                return profileEndpoint == normalizedEndpoint && profileModel == normalizedModel
            } ?? .custom
        }
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
