import AppKit
import Foundation

public enum VoiceInputStatus: Equatable, Sendable {
    case idle
    case listening
    case transcribing
    case polishing
    case inserting
    case fallbackInserted(String)
    case error(String)
}

@MainActor
public final class VoiceInputCoordinator {
    public typealias ConfigProvider = @MainActor () -> VoiceInputConfig
    public typealias TargetApplicationProvider = @MainActor () -> NSRunningApplication?
    public typealias StartRecording = @MainActor () async throws -> Void
    public typealias StopRecording = @MainActor () async throws -> URL
    public typealias CancelRecording = @MainActor () async -> Void
    public typealias Transcribe = @MainActor (SpeechTranscriptionRequest) async throws -> SpeechTranscriptionResult
    public typealias Cleanup = @MainActor (String, String) async throws -> String
    public typealias Insert = @MainActor (String, NSRunningApplication) async throws -> Void
    public typealias StatusHandler = @MainActor (VoiceInputStatus) -> Void

    private enum State {
        case idle
        case starting
        case listening
        case transcribing
        case polishing
        case inserting
        case cancelling
    }

    private let configProvider: ConfigProvider
    private let targetApplicationProvider: TargetApplicationProvider
    private let startRecordingHandler: StartRecording
    private let stopRecordingHandler: StopRecording
    private let cancelRecordingHandler: CancelRecording
    private let transcribeHandler: Transcribe
    private let cleanupHandler: Cleanup
    private let insertHandler: Insert
    private let statusHandler: StatusHandler
    private var state: State = .idle
    private var sessionID = 0

    public init(
        configProvider: @escaping ConfigProvider,
        targetApplicationProvider: @escaping TargetApplicationProvider,
        startRecording: @escaping StartRecording,
        stopRecording: @escaping StopRecording,
        cancelRecording: @escaping CancelRecording,
        transcribe: @escaping Transcribe,
        cleanup: @escaping Cleanup,
        insert: @escaping Insert,
        statusHandler: @escaping StatusHandler
    ) {
        self.configProvider = configProvider
        self.targetApplicationProvider = targetApplicationProvider
        self.startRecordingHandler = startRecording
        self.stopRecordingHandler = stopRecording
        self.cancelRecordingHandler = cancelRecording
        self.transcribeHandler = transcribe
        self.cleanupHandler = cleanup
        self.insertHandler = insert
        self.statusHandler = statusHandler
    }

    public func toggle() async {
        switch state {
        case .idle:
            await start()
        case .listening:
            await stop()
        case .starting, .transcribing, .polishing, .inserting, .cancelling:
            return
        }
    }

    public func start() async {
        guard case .idle = state else {
            return
        }

        sessionID += 1
        let activeSessionID = sessionID
        state = .starting
        do {
            try await startRecordingHandler()
            guard activeSessionID == sessionID else {
                await cancelRecordingHandler()
                return
            }
            state = .listening
            statusHandler(.listening)
        } catch {
            guard activeSessionID == sessionID else {
                return
            }
            state = .idle
            statusHandler(.error(userFacingMessage(for: error)))
        }
    }

    public func stop() async {
        guard case .listening = state else {
            return
        }

        let activeSessionID = sessionID
        do {
            state = .transcribing
            statusHandler(.transcribing)
            let audioURL = try await stopRecordingHandler()
            let config = configProvider()
            let transcription: SpeechTranscriptionResult
            do {
                transcription = try await transcribeHandler(SpeechTranscriptionRequest(
                    audioFileURL: audioURL,
                    model: config.speechModel,
                    timeoutSeconds: 20
                ))
            } catch {
                guard activeSessionID == sessionID else {
                    return
                }
                state = .idle
                statusHandler(.error(transcriptionFailureMessage(for: error)))
                return
            }
            guard activeSessionID == sessionID else {
                return
            }

            let transcript = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                state = .idle
                statusHandler(.error(SpeechTranscriptionError.emptyResponse.errorDescription ?? "No speech was recognized."))
                return
            }

            let finalText: String
            if config.autoProcessTranscription {
                state = .polishing
                statusHandler(.polishing)
                do {
                    finalText = try await cleanupHandler(transcript, config.voiceCleanupPromptModeID)
                } catch {
                    try await insertText(transcript)
                    guard activeSessionID == sessionID else {
                        return
                    }
                    state = .idle
                    statusHandler(.fallbackInserted(cleanupFailureMessage(for: error)))
                    statusHandler(.idle)
                    return
                }
            } else {
                finalText = transcript
            }

            try await insertText(finalText)
            guard activeSessionID == sessionID else {
                return
            }
            state = .idle
            statusHandler(.idle)
        } catch {
            guard activeSessionID == sessionID else {
                return
            }
            state = .idle
            statusHandler(.error(userFacingMessage(for: error)))
        }
    }

    public func cancel() async {
        switch state {
        case .starting, .listening:
            sessionID += 1
            state = .cancelling
            await cancelRecordingHandler()
            state = .idle
            statusHandler(.idle)
        case .idle, .transcribing, .polishing, .inserting, .cancelling:
            sessionID += 1
            state = .idle
            statusHandler(.idle)
        }
    }

    private func insertText(_ text: String) async throws {
        guard let targetApplication = targetApplicationProvider() else {
            throw VoiceInputCoordinatorError.missingTargetApplication
        }

        state = .inserting
        statusHandler(.inserting)
        try await insertHandler(text, targetApplication)
    }

    private func transcriptionFailureMessage(for error: Error) -> String {
        switch error {
        case SpeechTranscriptionError.emptyAudio:
            return SpeechTranscriptionError.emptyAudio.errorDescription ?? "No audio was recorded."
        case SpeechTranscriptionError.emptyResponse:
            return SpeechTranscriptionError.emptyResponse.errorDescription ?? "No speech was recognized."
        default:
            return "Transcription failed. Please try again."
        }
    }

    private func cleanupFailureMessage(for error: Error) -> String {
        "Cleanup failed. Inserted transcription."
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return String(describing: error)
    }
}

public enum VoiceInputCoordinatorError: Error, Equatable, LocalizedError {
    case missingTargetApplication

    public var errorDescription: String? {
        switch self {
        case .missingTargetApplication:
            return "No target app is available."
        }
    }
}
