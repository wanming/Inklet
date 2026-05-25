import Foundation

public struct SpeechTranscriptionRequest: Equatable, Sendable {
    public var audioFileURL: URL
    public var model: String
    public var timeoutSeconds: TimeInterval

    public init(audioFileURL: URL, model: String, timeoutSeconds: TimeInterval) {
        self.audioFileURL = audioFileURL
        self.model = model
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct SpeechTranscriptionResult: Equatable, Sendable {
    public var text: String
    public var providerMetadata: [String: String]

    public init(text: String, providerMetadata: [String: String] = [:]) {
        self.text = text
        self.providerMetadata = providerMetadata
    }
}

public enum SpeechTranscriptionError: Error, Equatable, LocalizedError {
    case emptyAudio
    case emptyResponse
    case invalidEndpoint
    case provider(String)

    public var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "No audio was recorded."
        case .emptyResponse:
            return "No speech was recognized."
        case .invalidEndpoint:
            return "Speech transcription endpoint is invalid."
        case .provider(let message):
            return message
        }
    }
}

public protocol SpeechTranscriptionProvider: Sendable {
    func transcribe(_ request: SpeechTranscriptionRequest) async throws -> SpeechTranscriptionResult
}
