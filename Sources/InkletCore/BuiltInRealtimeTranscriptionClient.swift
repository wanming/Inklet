import Foundation

/// Live Dictation on the built-in engine. The speech model transcribes whole clips, so the client
/// splits the hold into segments at pauses and keeps re-transcribing the open segment while
/// someone speaks. Each result replaces the provisional text in the draft; a segment's text becomes
/// final once a pause closes it, and the last segment is finished when the hold ends.
public actor BuiltInRealtimeTranscriptionClient: RealtimeTranscriptionClient {
    public struct Tuning: Equatable, Sendable {
        /// The capture format: 16-bit mono PCM at this rate.
        public var sampleRate = 24_000
        /// New audio needed before the open segment is transcribed again.
        public var refreshSeconds = 0.6
        /// Silence that closes a segment.
        public var pauseSeconds = 1.0
        /// Past this length, a shorter pause closes the segment, so each request stays small.
        public var longSegmentSeconds = 12.0
        public var shortPauseSeconds = 0.4
        /// A segment is closed at this length even without a pause.
        public var maxSegmentSeconds = 30.0
        /// A frame counts as speech when its RMS is this multiple of the noise floor, within these
        /// bounds: never at or below `minimumSpeechLevel`, and always above `alwaysSpeechLevel`, so
        /// speaking from the first frame still counts.
        public var speechOverNoiseFloor: Float = 3
        public var minimumSpeechLevel: Float = 0.005
        public var alwaysSpeechLevel: Float = 0.02
        public var requestTimeoutSeconds: TimeInterval = 30
        /// A cold start loads the model from disk, which can take longer than a network handshake.
        public var minimumStartupTimeoutSeconds: TimeInterval = 60

        public init() {}
    }

    /// Transcribes one WAV clip.
    public typealias Recognize = @Sendable (Data) async throws -> String
    /// Starts the engine within the given seconds and returns a recognizer for it.
    public typealias Connect = @Sendable (TimeInterval) async throws -> Recognize

    private enum State {
        case fresh
        case connecting
        case ready
        case committed
        case finished
        case closed
    }

    private enum Job {
        case finalizeSegment(Range<Int>)
        case refresh(Range<Int>)
        case finish(Range<Int>)
    }

    private static let itemID = "built-in"
    private static let frameSeconds = 0.02

    private let tuning: Tuning
    private let connectEngine: Connect
    private var recognize: Recognize?
    private var state: State = .fresh

    private var audio = Data()
    private var segmentStart = 0
    private var closedSegments: [Range<Int>] = []
    private var lastRefreshEnd = 0
    private var segmentHasSpeech = false
    private var trailingSilenceBytes = 0
    private var noiseFloor: Float?
    private var pendingFrameBytes = Data()

    private var committedText = ""
    private var openSegmentText = ""
    private var sequence = 0

    private var worker: Task<Void, Never>?
    private var workWaiter: CheckedContinuation<Void, Never>?
    private var pendingEvents: [RealtimeTranscriptionEvent] = []
    private var eventWaiter: CheckedContinuation<RealtimeTranscriptionEvent, Error>?
    private var failure: Error?

    public init(tuning: Tuning = Tuning(), connect: @escaping Connect) {
        self.tuning = tuning
        self.connectEngine = connect
    }

    public init(
        model: BuiltInDictationModel = .recommended,
        server: BuiltInModelServer = .dictation,
        session: URLSession = .shared,
        tuning: Tuning = Tuning()
    ) {
        self.init(tuning: tuning) { timeoutSeconds in
            let connection = try await server.connection(
                for: model.weights,
                projector: model.projector,
                startupTimeoutSeconds: timeoutSeconds
            )
            let recognizer = BuiltInSpeechRecognizer(connection: connection, modelID: model.weights.id, session: session)
            return { wav in
                try await recognizer.transcribe(wav: wav, timeoutSeconds: tuning.requestTimeoutSeconds)
            }
        }
    }

    public func connect(timeoutSeconds: TimeInterval) async throws {
        guard case .fresh = state else {
            throw RealtimeTranscriptionError.invalidState
        }
        state = .connecting
        let recognize: Recognize
        do {
            recognize = try await connectEngine(max(timeoutSeconds, tuning.minimumStartupTimeoutSeconds))
        } catch {
            if case .connecting = state {
                state = .closed
            }
            throw error
        }
        guard case .connecting = state else {
            throw RealtimeTranscriptionError.connectionClosed
        }
        self.recognize = recognize
        state = .ready
        worker = Task { [weak self] in
            await self?.runJobs()
        }
    }

    public func appendPCM16(_ data: Data) async throws {
        guard case .ready = state else {
            throw RealtimeTranscriptionError.invalidState
        }
        guard !data.isEmpty else { return }
        audio.append(data)
        analyzeLevels(of: data)
        closeSegmentIfNeeded()
        wakeWorker()
    }

    public func commit() async throws {
        guard case .ready = state else {
            throw RealtimeTranscriptionError.invalidState
        }
        state = .committed
        wakeWorker()
    }

    public func nextEvent() async throws -> RealtimeTranscriptionEvent {
        if !pendingEvents.isEmpty {
            return pendingEvents.removeFirst()
        }
        if let failure {
            throw failure
        }
        if case .closed = state {
            throw RealtimeTranscriptionError.connectionClosed
        }
        guard eventWaiter == nil else {
            throw RealtimeTranscriptionError.invalidState
        }
        return try await withCheckedThrowingContinuation { continuation in
            eventWaiter = continuation
        }
    }

    public func close() async {
        state = .closed
        worker?.cancel()
        worker = nil
        wakeWorker()
        eventWaiter?.resume(throwing: RealtimeTranscriptionError.connectionClosed)
        eventWaiter = nil
    }

    // MARK: - Segments

    private var bytesPerSecond: Double {
        Double(tuning.sampleRate * 2)
    }

    private func byteCount(seconds: Double) -> Int {
        Int(seconds * bytesPerSecond) & ~1
    }

    /// Tracks whether the open segment holds speech and how long it has been quiet, from the RMS
    /// of 20 ms frames. The quietest frame so far stands in for the room's noise floor.
    private func analyzeLevels(of data: Data) {
        pendingFrameBytes.append(data)
        let frameBytes = byteCount(seconds: Self.frameSeconds)
        while pendingFrameBytes.count >= frameBytes {
            let frame = pendingFrameBytes.prefix(frameBytes)
            pendingFrameBytes.removeFirst(frameBytes)
            let level = Self.rms(ofPCM16: frame)
            noiseFloor = min(noiseFloor ?? level, level)
            let threshold = max(
                tuning.minimumSpeechLevel,
                min((noiseFloor ?? 0) * tuning.speechOverNoiseFloor, tuning.alwaysSpeechLevel)
            )
            if level > threshold {
                segmentHasSpeech = true
                trailingSilenceBytes = 0
            } else {
                trailingSilenceBytes += frameBytes
            }
        }
    }

    static func rms(ofPCM16 frame: Data) -> Float {
        let sampleCount = frame.count / 2
        guard sampleCount > 0 else { return 0 }
        var sumOfSquares: Float = 0
        frame.withUnsafeBytes { buffer in
            for index in 0..<sampleCount {
                let sample = Int16(littleEndian: buffer.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))
                let value = Float(sample) / 32_768
                sumOfSquares += value * value
            }
        }
        return (sumOfSquares / Float(sampleCount)).squareRoot()
    }

    private func closeSegmentIfNeeded() {
        let segmentBytes = audio.count - segmentStart
        let pauseBytes = byteCount(
            seconds: segmentBytes > byteCount(seconds: tuning.longSegmentSeconds)
                ? tuning.shortPauseSeconds
                : tuning.pauseSeconds
        )
        let endsAtPause = segmentHasSpeech && trailingSilenceBytes >= pauseBytes
        guard endsAtPause || segmentBytes >= byteCount(seconds: tuning.maxSegmentSeconds) else { return }
        closedSegments.append(segmentStart..<audio.count)
        segmentStart = audio.count
        lastRefreshEnd = audio.count
        segmentHasSpeech = false
    }

    private func nextJob() -> Job? {
        if !closedSegments.isEmpty {
            return .finalizeSegment(closedSegments.removeFirst())
        }
        switch state {
        case .committed:
            state = .finished
            // A quiet tail after earlier segments is only the pause before release. When no frame
            // ever counted as speech, the whole hold is still transcribed in case the voice was soft.
            let tailIsQuiet = !segmentHasSpeech && segmentStart > 0
            return .finish(tailIsQuiet ? segmentStart..<segmentStart : segmentStart..<audio.count)
        case .ready:
            guard segmentHasSpeech,
                  audio.count - lastRefreshEnd >= byteCount(seconds: tuning.refreshSeconds)
            else {
                return nil
            }
            lastRefreshEnd = audio.count
            return .refresh(segmentStart..<audio.count)
        case .fresh, .connecting, .finished, .closed:
            return nil
        }
    }

    private func runJobs() async {
        while !Task.isCancelled {
            guard let job = nextJob() else {
                if case .ready = state {
                    await waitForWork()
                    continue
                }
                return
            }
            do {
                try await perform(job)
            } catch {
                fail(error)
                return
            }
            if case .finish = job {
                return
            }
        }
    }

    private func perform(_ job: Job) async throws {
        switch job {
        case .finalizeSegment(let range):
            let text = try await transcribe(range)
            committedText = Self.joined(committedText, text)
            openSegmentText = ""
            emit(.replaced(
                eventID: nil,
                sequence: nextSequence(),
                itemID: Self.itemID,
                contentIndex: 0,
                transcript: committedText
            ))
        case .refresh(let range):
            let text = try await transcribe(range)
            // A pause may have closed this segment while it was transcribed; its final text follows.
            guard range.lowerBound == segmentStart, case .ready = state else { return }
            openSegmentText = text
            emit(.replaced(
                eventID: nil,
                sequence: nextSequence(),
                itemID: Self.itemID,
                contentIndex: 0,
                transcript: Self.joined(committedText, openSegmentText)
            ))
        case .finish(let range):
            if !range.isEmpty {
                committedText = Self.joined(committedText, try await transcribe(range))
            }
            emit(.completed(
                eventID: nil,
                sequence: nextSequence(),
                itemID: Self.itemID,
                contentIndex: 0,
                transcript: committedText
            ))
        }
    }

    private func transcribe(_ range: Range<Int>) async throws -> String {
        guard let recognize else {
            throw RealtimeTranscriptionError.invalidState
        }
        let wav = PCM16WAV.wav(fromPCM16: audio.subdata(in: range), sampleRate: tuning.sampleRate)
        return try await recognize(wav)
    }

    /// Chinese and Japanese segments join directly; Latin words get a space between them.
    static func joined(_ first: String, _ second: String) -> String {
        guard let last = first.last, let next = second.first else {
            return first + second
        }
        let needsSpace = last.isASCII && !last.isWhitespace && next.isASCII && (next.isLetter || next.isNumber)
        return needsSpace ? first + " " + second : first + second
    }

    private func nextSequence() -> Int {
        sequence += 1
        return sequence
    }

    // MARK: - Waiting

    private func waitForWork() async {
        await withCheckedContinuation { continuation in
            workWaiter = continuation
        }
    }

    private func wakeWorker() {
        workWaiter?.resume()
        workWaiter = nil
    }

    private func emit(_ event: RealtimeTranscriptionEvent) {
        if let eventWaiter {
            self.eventWaiter = nil
            eventWaiter.resume(returning: event)
        } else {
            pendingEvents.append(event)
        }
    }

    private func fail(_ error: Error) {
        failure = error
        eventWaiter?.resume(throwing: error)
        eventWaiter = nil
    }
}
