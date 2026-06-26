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

    public enum RecordingMode: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        case tapToToggle
        case pressAndHold
        case doubleTap

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

    public enum PostTranscriptionAction: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        case useDefaultPromptMode
        case askEachTime
        case insertRawTranscript

        public var id: String { rawValue }
    }

    public var shortcut: Shortcut
    public var speechProviderID: String
    public var speechEndpoint: String
    public var speechModel: String
    public var microphoneDeviceID: String?
    public var autoProcessTranscription: Bool
    public var postTranscriptionAction: PostTranscriptionAction
    public var recordingMode: RecordingMode
    public var voiceCleanupPromptModeID: String

    public init(
        shortcut: Shortcut,
        speechProviderID: String,
        speechEndpoint: String,
        speechModel: String,
        microphoneDeviceID: String?,
        autoProcessTranscription: Bool,
        postTranscriptionAction: PostTranscriptionAction? = nil,
        recordingMode: RecordingMode = .pressAndHold,
        voiceCleanupPromptModeID: String
    ) {
        self.shortcut = shortcut
        self.speechProviderID = speechProviderID
        self.speechEndpoint = speechEndpoint
        self.speechModel = speechModel
        self.microphoneDeviceID = microphoneDeviceID
        let resolvedAction = postTranscriptionAction
            ?? (autoProcessTranscription ? .useDefaultPromptMode : .insertRawTranscript)
        self.autoProcessTranscription = resolvedAction != .insertRawTranscript
        self.postTranscriptionAction = resolvedAction
        self.recordingMode = recordingMode
        self.voiceCleanupPromptModeID = voiceCleanupPromptModeID
    }

    public static func defaultConfig() -> VoiceInputConfig {
        VoiceInputConfig(
            shortcut: .rightOption,
            speechProviderID: openAISpeechProviderID,
            speechEndpoint: defaultSpeechEndpoint,
            speechModel: defaultSpeechModel,
            microphoneDeviceID: nil,
            autoProcessTranscription: true,
            postTranscriptionAction: .useDefaultPromptMode,
            recordingMode: .pressAndHold,
            voiceCleanupPromptModeID: PromptMode.voiceCleanupID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case shortcut
        case speechProviderID
        case speechEndpoint
        case speechModel
        case microphoneDeviceID
        case autoProcessTranscription
        case postTranscriptionAction
        case recordingMode
        case voiceCleanupPromptModeID
    }

    public init(from decoder: Decoder) throws {
        let defaults = VoiceInputConfig.defaultConfig()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let autoProcessTranscription = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoProcessTranscription
        ) ?? defaults.autoProcessTranscription

        self.init(
            shortcut: try container.decodeIfPresent(Shortcut.self, forKey: .shortcut) ?? defaults.shortcut,
            speechProviderID: try container.decodeIfPresent(
                String.self,
                forKey: .speechProviderID
            ) ?? defaults.speechProviderID,
            speechEndpoint: try container.decodeIfPresent(
                String.self,
                forKey: .speechEndpoint
            ) ?? defaults.speechEndpoint,
            speechModel: try container.decodeIfPresent(String.self, forKey: .speechModel) ?? defaults.speechModel,
            microphoneDeviceID: try container.decodeIfPresent(String.self, forKey: .microphoneDeviceID),
            autoProcessTranscription: autoProcessTranscription,
            postTranscriptionAction: try container.decodeIfPresent(
                PostTranscriptionAction.self,
                forKey: .postTranscriptionAction
            ),
            recordingMode: try container.decodeIfPresent(RecordingMode.self, forKey: .recordingMode)
                ?? defaults.recordingMode,
            voiceCleanupPromptModeID: try container.decodeIfPresent(
                String.self,
                forKey: .voiceCleanupPromptModeID
            ) ?? defaults.voiceCleanupPromptModeID
        )
    }
}
