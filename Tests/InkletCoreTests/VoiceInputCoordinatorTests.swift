import AppKit
import XCTest
@testable import InkletCore

@MainActor
final class VoiceInputCoordinatorTests: XCTestCase {
    func testStartBeginsRecordingAndShowsListening() async {
        let harness = VoiceInputHarness()

        await harness.coordinator.start()

        XCTAssertEqual(harness.startRecordingCount, 1)
        XCTAssertEqual(harness.statuses, [.listening])
    }

    func testRepeatedToggleDuringStartupStartsRecordingOnce() async {
        let harness = VoiceInputHarness()
        harness.pauseStartRecording = true

        let startTask = Task {
            await harness.coordinator.toggle()
        }
        await Task.yield()
        await harness.coordinator.toggle()

        XCTAssertEqual(harness.startRecordingCount, 1)
        XCTAssertEqual(harness.statuses, [])

        harness.resumeStartRecording()
        await startTask.value

        XCTAssertEqual(harness.startRecordingCount, 1)
        XCTAssertEqual(harness.statuses, [.listening])
    }

    func testCancelDuringListeningStopsRecordingAndShowsIdle() async {
        let harness = VoiceInputHarness()

        await harness.coordinator.start()
        await harness.coordinator.cancel()

        XCTAssertEqual(harness.cancelRecordingCount, 1)
        XCTAssertEqual(harness.insertedTexts, [])
        XCTAssertEqual(harness.statuses, [.listening, .idle])
    }

    func testStopWithAutoProcessingDisabledInsertsRawTranscription() async {
        let harness = VoiceInputHarness(config: VoiceInputConfig(
            shortcut: .rightOption,
            speechProviderID: VoiceInputConfig.openAISpeechProviderID,
            speechEndpoint: VoiceInputConfig.defaultSpeechEndpoint,
            speechModel: VoiceInputConfig.defaultSpeechModel,
            autoProcessTranscription: false,
            voiceCleanupPromptModeID: PromptMode.voiceCleanupID
        ))
        harness.transcriptionText = "raw transcript"

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, ["raw transcript"])
        XCTAssertEqual(harness.cleanupInputs, [])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .inserting, .idle])
    }

    func testRawTranscriptionSuccessRecordsHistory() async {
        let harness = VoiceInputHarness(config: VoiceInputConfig(
            shortcut: .rightOption,
            speechProviderID: VoiceInputConfig.openAISpeechProviderID,
            speechEndpoint: VoiceInputConfig.defaultSpeechEndpoint,
            speechModel: "gpt-speech-test",
            autoProcessTranscription: false,
            voiceCleanupPromptModeID: PromptMode.voiceCleanupID
        ))
        harness.transcriptionText = "raw transcript"

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.recordedHistory, [
            VoiceInputHistoryEvent(
                transcript: "raw transcript",
                finalText: "raw transcript",
                cleanupPromptModeID: nil,
                speechModel: "gpt-speech-test",
                cleanupFallback: false
            )
        ])
    }

    func testStopWithAutoProcessingEnabledInsertsCleanedText() async {
        let harness = VoiceInputHarness()
        harness.transcriptionText = "um hello there"
        harness.cleanedText = "Hello there."

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.cleanupInputs, ["um hello there"])
        XCTAssertEqual(harness.insertedTexts, ["Hello there."])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .polishing, .inserting, .idle])
    }

    func testCleanedTranscriptionSuccessRecordsHistory() async {
        let harness = VoiceInputHarness()
        harness.transcriptionText = "um hello there"
        harness.cleanedText = "Hello there."

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.recordedHistory, [
            VoiceInputHistoryEvent(
                transcript: "um hello there",
                finalText: "Hello there.",
                cleanupPromptModeID: PromptMode.voiceCleanupID,
                speechModel: VoiceInputConfig.defaultSpeechModel,
                cleanupFallback: false
            )
        ])
    }

    func testCleanupFailureFallsBackToRawTranscription() async {
        let harness = VoiceInputHarness()
        harness.transcriptionText = "raw transcript"
        harness.cleanupError = TransformationError.provider("cleanup failed")

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, ["raw transcript"])
        XCTAssertEqual(harness.statuses, [
            .listening,
            .transcribing,
            .polishing,
            .inserting,
            .fallbackInserted("Cleanup failed. Inserted transcription."),
            .idle
        ])
    }

    func testCleanupFallbackRecordsRawHistory() async {
        let harness = VoiceInputHarness()
        harness.transcriptionText = "raw transcript"
        harness.cleanupError = TransformationError.provider("cleanup failed")

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.recordedHistory, [
            VoiceInputHistoryEvent(
                transcript: "raw transcript",
                finalText: "raw transcript",
                cleanupPromptModeID: PromptMode.voiceCleanupID,
                speechModel: VoiceInputConfig.defaultSpeechModel,
                cleanupFallback: true
            )
        ])
    }

    func testTranscriptionProviderFailureShowsShortError() async {
        let harness = VoiceInputHarness()
        harness.transcriptionError = SpeechTranscriptionError.provider(
            "OpenAI speech request failed: Invalid API key with a very long provider detail."
        )

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, [])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .error("Transcription failed. Please try again.")])
    }

    func testEmptyTranscriptionErrorKeepsSpecificShortMessage() async {
        let harness = VoiceInputHarness()
        harness.transcriptionError = SpeechTranscriptionError.emptyResponse

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, [])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .error("No speech was recognized.")])
    }

    func testEmptyTranscriptionInsertsNothing() async {
        let harness = VoiceInputHarness()
        harness.transcriptionText = "   "

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, [])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .error("No speech was recognized.")])
    }

    func testMissingTargetAppInsertsNothing() async {
        let harness = VoiceInputHarness(targetApplication: nil)
        harness.transcriptionText = "hello"

        await harness.coordinator.start()
        await harness.coordinator.stop()

        XCTAssertEqual(harness.insertedTexts, [])
        XCTAssertEqual(harness.statuses, [.listening, .transcribing, .polishing, .error("No target app is available.")])
    }
}

@MainActor
private final class VoiceInputHarness {
    var startRecordingCount = 0
    var stopRecordingCount = 0
    var cancelRecordingCount = 0
    var insertedTexts: [String] = []
    var cleanupInputs: [String] = []
    var recordedHistory: [VoiceInputHistoryEvent] = []
    var statuses: [VoiceInputStatus] = []
    var transcriptionText = "hello"
    var cleanedText = "Hello."
    var transcriptionError: Error?
    var cleanupError: Error?
    var pauseStartRecording = false
    private var startRecordingContinuation: CheckedContinuation<Void, Never>?

    var coordinator: VoiceInputCoordinator!

    init(
        config: VoiceInputConfig = VoiceInputConfig.defaultConfig(),
        targetApplication: NSRunningApplication? = .current
    ) {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-input-test")
            .appendingPathExtension("m4a")

        coordinator = VoiceInputCoordinator(
            configProvider: { config },
            targetApplicationProvider: { targetApplication },
            startRecording: { [weak self] in
                self?.startRecordingCount += 1
                if self?.pauseStartRecording == true {
                    await withCheckedContinuation { continuation in
                        self?.startRecordingContinuation = continuation
                    }
                }
            },
            stopRecording: { [weak self] in
                self?.stopRecordingCount += 1
                return audioURL
            },
            cancelRecording: { [weak self] in
                self?.cancelRecordingCount += 1
            },
            transcribe: { [weak self] request in
                if let transcriptionError = self?.transcriptionError {
                    throw transcriptionError
                }
                return SpeechTranscriptionResult(text: self?.transcriptionText ?? "")
            },
            cleanup: { [weak self] source, _ in
                self?.cleanupInputs.append(source)
                if let cleanupError = self?.cleanupError {
                    throw cleanupError
                }
                return self?.cleanedText ?? source
            },
            insert: { [weak self] text, _ in
                self?.insertedTexts.append(text)
            },
            recordHistory: { [weak self] event in
                self?.recordedHistory.append(event)
            },
            statusHandler: { [weak self] status in
                self?.statuses.append(status)
            }
        )
    }

    func resumeStartRecording() {
        pauseStartRecording = false
        startRecordingContinuation?.resume()
        startRecordingContinuation = nil
    }
}
