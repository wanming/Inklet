import XCTest
@testable import Inklet
@testable import InkletCore

final class BuiltInDictationTests: XCTestCase {
    private let sampleRate = 24_000

    // MARK: - Model and server

    func testDictationModelPinsBothFilesFromOneRevision() {
        let model = BuiltInDictationModel.recommended
        XCTAssertEqual(model, .qwen3ASR06B)
        XCTAssertEqual(BuiltInDictationModel.model(id: "qwen3-asr-0.6b"), .qwen3ASR06B)
        XCTAssertEqual(model.files.map(\.fileName), ["Qwen3-ASR-0.6B-Q8_0.gguf", "mmproj-Qwen3-ASR-0.6B-Q8_0.gguf"])
        XCTAssertEqual(model.sizeBytes, 804_749_248 + 214_392_480)
        XCTAssertEqual(
            model.weights.downloadURL.absoluteString,
            "https://huggingface.co/ggml-org/Qwen3-ASR-0.6B-GGUF/resolve/928ab958557df9aa2ef1c93e0e83c7ad0933fae2/Qwen3-ASR-0.6B-Q8_0.gguf"
        )
        for file in model.files {
            XCTAssertEqual(file.sha256.count, 64, file.id)
            XCTAssertEqual(file.revision, model.weights.revision, file.id)
        }
        // The speech model is not a writing model.
        XCTAssertTrue(Set(BuiltInModel.all.map(\.id)).isDisjoint(with: model.files.map(\.id)))
    }

    func testDictationServerKeepsTheModelLoadedFrom16GB() {
        let gigabyte: UInt64 = 1_073_741_824
        let threshold = BuiltInDictationModel.keepsModelLoadedMemoryGB
        XCTAssertEqual(threshold, 16)
        XCTAssertEqual(BuiltInModelServer.idleUnloadSeconds(forPhysicalMemoryBytes: 8 * gigabyte, keepsModelLoadedMemoryGB: threshold), 300)
        XCTAssertNil(BuiltInModelServer.idleUnloadSeconds(forPhysicalMemoryBytes: 16 * gigabyte, keepsModelLoadedMemoryGB: threshold))
        XCTAssertEqual(BuiltInModelServer.idleUnloadSeconds(forPhysicalMemoryBytes: 16 * gigabyte), 300)
    }

    func testDictationServerLoadsTheAudioEncoder() {
        let arguments = BuiltInModelServer.arguments(
            modelPath: "/models/asr.gguf",
            projectorPath: "/models/mmproj-asr.gguf",
            modelID: "qwen3-asr-0.6b-weights",
            port: 52_000,
            apiKey: "secret"
        )

        XCTAssertEqual(value(after: "--mmproj", in: arguments), "/models/mmproj-asr.gguf")
        XCTAssertEqual(value(after: "--host", in: arguments), "127.0.0.1")
        XCTAssertFalse(
            BuiltInModelServer.arguments(modelPath: "/models/qwen.gguf", modelID: "qwen3.5-4b", port: 52_000, apiKey: "secret")
                .contains("--mmproj")
        )
    }

    // MARK: - Recognizer

    func testWAVHeaderDescribesMono16BitPCM() {
        let pcm = Data(repeating: 1, count: 480)
        let wav = PCM16WAV.wav(fromPCM16: pcm, sampleRate: sampleRate)

        XCTAssertEqual(wav.count, 44 + pcm.count)
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: wav.subdata(in: 8..<16), encoding: .ascii), "WAVEfmt ")
        XCTAssertEqual(String(data: wav.subdata(in: 36..<40), encoding: .ascii), "data")
        XCTAssertEqual(uint32(at: 24, in: wav), UInt32(sampleRate))
        XCTAssertEqual(uint32(at: 40, in: wav), UInt32(pcm.count))
        XCTAssertEqual(wav.suffix(pcm.count), pcm)
    }

    func testRecognizerSendsTheClipAsInputAudio() throws {
        let body = try BuiltInSpeechRecognizer.requestBody(wav: Data([1, 2, 3]), modelID: "qwen3-asr-0.6b-weights")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let message = try XCTUnwrap((json["messages"] as? [[String: Any]])?.first)
        let part = try XCTUnwrap((message["content"] as? [[String: Any]])?.first)
        let audio = try XCTUnwrap(part["input_audio"] as? [String: String])

        XCTAssertEqual(json["model"] as? String, "qwen3-asr-0.6b-weights")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(part["type"] as? String, "input_audio")
        XCTAssertEqual(audio, ["data": Data([1, 2, 3]).base64EncodedString(), "format": "wav"])
    }

    func testRecognizerKeepsOnlyTheTranscript() throws {
        XCTAssertEqual(BuiltInSpeechRecognizer.transcript(fromModelOutput: "language Chinese<asr_text>我想用 Inklet 写邮件。"), "我想用 Inklet 写邮件。")
        XCTAssertEqual(BuiltInSpeechRecognizer.transcript(fromModelOutput: "language None<asr_text>"), "")
        XCTAssertEqual(BuiltInSpeechRecognizer.transcript(fromModelOutput: "language English"), "")
        XCTAssertEqual(BuiltInSpeechRecognizer.transcript(fromModelOutput: " Hello there. \n"), "Hello there.")

        let response = Data(#"{"choices":[{"message":{"content":"language English<asr_text>Hi."}}]}"#.utf8)
        XCTAssertEqual(try BuiltInSpeechRecognizer.transcript(fromResponse: response), "Hi.")
        XCTAssertThrowsError(try BuiltInSpeechRecognizer.transcript(fromResponse: Data(#"{"error":{}}"#.utf8))) {
            XCTAssertEqual($0 as? RealtimeTranscriptionError, .invalidMessage)
        }
    }

    // MARK: - Realtime client

    func testSegmentsJoinWithSpacesOnlyBetweenLatinWords() {
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.joined("你好。", "今天开会"), "你好。今天开会")
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.joined("See you.", "Thanks"), "See you. Thanks")
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.joined("", "Hi"), "Hi")
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.joined("Hi", ""), "Hi")
    }

    func testLevelIsTheRMSOfTheFrame() {
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.rms(ofPCM16: pcm(seconds: 0.02, amplitude: 0)), 0)
        XCTAssertEqual(BuiltInRealtimeTranscriptionClient.rms(ofPCM16: pcm(seconds: 0.02, amplitude: 16_384)), 0.5, accuracy: 0.001)
    }

    func testStartingGivesTheModelTimeToLoad() async throws {
        let timeouts = Recorder<TimeInterval>()
        let client = BuiltInRealtimeTranscriptionClient { timeout in
            await timeouts.append(timeout)
            return { _ in "" }
        }

        try await client.connect(timeoutSeconds: 5)

        let recorded = await timeouts.values
        XCTAssertEqual(recorded, [BuiltInRealtimeTranscriptionClient.Tuning().minimumStartupTimeoutSeconds])
    }

    func testDraftUpdatesWhileSpeakingAndSettlesAtPauses() async throws {
        let clips = Recorder<Int>()
        let client = BuiltInRealtimeTranscriptionClient { _ in
            { wav in
                await clips.append(wav.count - 44)
                return "word"
            }
        }
        try await client.connect(timeoutSeconds: 5)

        let speech = pcm(seconds: 1, amplitude: 8_000)
        let pause = pcm(seconds: 1.2, amplitude: 0)
        try await client.appendPCM16(speech)
        let refreshed = try await client.nextEvent()
        XCTAssertEqual(refreshed, replaced("word", sequence: 1))

        // A one-second pause closes the first segment.
        try await client.appendPCM16(pause)
        let settled = try await client.nextEvent()
        XCTAssertEqual(settled, replaced("word", sequence: 2))

        try await client.appendPCM16(speech)
        try await client.commit()

        var events: [RealtimeTranscriptionEvent] = []
        while true {
            let event = try await client.nextEvent()
            events.append(event)
            if case .completed = event { break }
        }
        guard case let .completed(_, _, itemID, contentIndex, transcript) = try XCTUnwrap(events.last) else {
            return XCTFail("Expected a completed transcript")
        }
        XCTAssertEqual(itemID, "built-in")
        XCTAssertEqual(contentIndex, 0)
        XCTAssertEqual(transcript, "word word")

        let lengths = await clips.values
        XCTAssertEqual(lengths.first, speech.count, "Refresh sends the open segment so far")
        XCTAssertEqual(lengths.dropFirst().first, speech.count + pause.count, "The closed segment includes its pause")
        XCTAssertEqual(lengths.last, speech.count, "Finishing sends only the last segment")
    }

    func testQuietTailAfterASegmentIsNotTranscribed() async throws {
        let clips = Recorder<Int>()
        let client = BuiltInRealtimeTranscriptionClient { _ in
            { wav in
                await clips.append(wav.count - 44)
                return "Hello."
            }
        }
        try await client.connect(timeoutSeconds: 5)

        let hold = pcm(seconds: 0.5, amplitude: 8_000) + pcm(seconds: 1.5, amplitude: 0)
        try await client.appendPCM16(hold)
        try await client.commit()

        var transcript: String?
        while transcript == nil {
            if case let .completed(_, _, _, _, text) = try await client.nextEvent() {
                transcript = text
            }
        }
        XCTAssertEqual(transcript, "Hello.")
        let lengths = await clips.values
        XCTAssertEqual(lengths, [hold.count])
    }

    func testSoftSpeechIsStillTranscribedWhenNothingCountedAsSpeech() async throws {
        let calls = Recorder<Int>()
        let client = BuiltInRealtimeTranscriptionClient { _ in
            { wav in
                await calls.append(wav.count)
                return ""
            }
        }
        try await client.connect(timeoutSeconds: 5)

        try await client.appendPCM16(pcm(seconds: 1, amplitude: 50))
        try await client.commit()

        let event = try await client.nextEvent()
        XCTAssertEqual(event, .completed(eventID: nil, sequence: 1, itemID: "built-in", contentIndex: 0, transcript: ""))
        let count = await calls.values.count
        XCTAssertEqual(count, 1)
    }

    func testRecognitionFailureEndsTheSession() async throws {
        let client = BuiltInRealtimeTranscriptionClient { _ in
            { _ in throw LocalModelError.engineFailedToStart }
        }
        try await client.connect(timeoutSeconds: 5)

        try await client.appendPCM16(pcm(seconds: 1, amplitude: 8_000))

        do {
            _ = try await client.nextEvent()
            XCTFail("Expected the failure")
        } catch {
            XCTAssertEqual(error as? LocalModelError, .engineFailedToStart)
        }
    }

    func testClosingWakesAWaitingReader() async throws {
        let client = BuiltInRealtimeTranscriptionClient { _ in { _ in "" } }
        try await client.connect(timeoutSeconds: 5)

        let reader = Task { try await client.nextEvent() }
        try await Task.sleep(nanoseconds: 50_000_000)
        await client.close()

        do {
            _ = try await reader.value
            XCTFail("Expected the session to close")
        } catch {
            XCTAssertEqual(error as? RealtimeTranscriptionError, .connectionClosed)
        }
    }

    // MARK: - App

    @MainActor
    func testDownloadStateCombinesBothFilesBySize() {
        XCTAssertEqual(
            BuiltInModelDownloads.combinedState([(sizeBytes: 300, state: .downloading(fraction: 0.5)), (sizeBytes: 100, state: .ready)]),
            .downloading(fraction: 0.625)
        )
        XCTAssertEqual(
            BuiltInModelDownloads.combinedState([(sizeBytes: 300, state: .verifying), (sizeBytes: 100, state: .ready)]),
            .verifying
        )
        XCTAssertEqual(
            BuiltInModelDownloads.combinedState([(sizeBytes: 300, state: .ready), (sizeBytes: 100, state: .ready)]),
            .ready
        )
        XCTAssertEqual(
            BuiltInModelDownloads.combinedState([(sizeBytes: 300, state: .ready), (sizeBytes: 100, state: .notDownloaded)]),
            .notDownloaded
        )
        XCTAssertEqual(
            BuiltInModelDownloads.combinedState([(sizeBytes: 300, state: .failed(message: "Offline")), (sizeBytes: 100, state: .ready)]),
            .failed(message: "Offline")
        )
    }

    @MainActor
    func testSpeechModelLoadsOnlyForOnDeviceDictationThatIsOn() {
        var voiceInput = VoiceInputConfig.defaultConfig()
        XCTAssertTrue(BuiltInDictationResidency.shouldLoad(voiceInput: voiceInput, isBuiltInEngineAvailable: true, isModelInstalled: true))
        XCTAssertFalse(BuiltInDictationResidency.shouldLoad(voiceInput: voiceInput, isBuiltInEngineAvailable: true, isModelInstalled: false))
        XCTAssertFalse(BuiltInDictationResidency.shouldLoad(voiceInput: voiceInput, isBuiltInEngineAvailable: false, isModelInstalled: true))

        voiceInput.isEnabled = false
        XCTAssertFalse(BuiltInDictationResidency.shouldLoad(voiceInput: voiceInput, isBuiltInEngineAvailable: true, isModelInstalled: true))

        voiceInput.isEnabled = true
        voiceInput.engine = .openAI
        XCTAssertFalse(BuiltInDictationResidency.shouldLoad(voiceInput: voiceInput, isBuiltInEngineAvailable: true, isModelInstalled: true))
    }

    // MARK: - Helpers

    private func pcm(seconds: Double, amplitude: Int16) -> Data {
        let sampleCount = byteCount(seconds: seconds) / 2
        var data = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            // A square wave keeps every 20 ms frame at the same level.
            let sample = index.isMultiple(of: 2) ? amplitude : -amplitude
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func byteCount(seconds: Double) -> Int {
        Int(seconds * Double(sampleRate * 2)) & ~1
    }

    private func replaced(_ transcript: String, sequence: Int) -> RealtimeTranscriptionEvent {
        .replaced(eventID: nil, sequence: sequence, itemID: "built-in", contentIndex: 0, transcript: transcript)
    }

    private func uint32(at offset: Int, in data: Data) -> UInt32 {
        data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

private actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []

    func append(_ value: Value) {
        values.append(value)
    }
}
