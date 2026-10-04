import Foundation
import XCTest
@testable import InkletCore

final class TransformationServiceTests: XCTestCase {
    func testSuccessfulProviderReturnsTrimmedResult() async throws {
        let service = TransformationService(provider: FakeLLMProvider(outputText: "  Hello.  "))

        let result = try await service.transform(
            sourceText: "  hello  ",
            mode: mode,
            model: "test-model",
            timeoutSeconds: 1
        )

        XCTAssertEqual(result.outputText, "Hello.")
    }

    func testEmptyProviderResponseThrowsEmptyResponse() async throws {
        let service = TransformationService(provider: FakeLLMProvider(outputText: " \n\t "))

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected emptyResponse")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .emptyResponse)
        }
    }

    func testTimeoutThrowsTimeout() async throws {
        let service = TransformationService(provider: FakeLLMProvider(
            outputText: "Hello.",
            delayNanoseconds: 500_000_000
        ))

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 0.01
            )
            XCTFail("Expected timeout")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .timeout)
        }
    }

    func testNetworkConnectionLostErrorHasSafeFallbackDescription() {
        XCTAssertEqual(
            TransformationError.networkConnectionLost.errorDescription,
            "网络连接中断，请重试"
        )
    }

    func testRetriesNetworkConnectionLostOnceAndReturnsSuccess() async throws {
        let provider = SequencedLLMProvider([
            .networkConnectionLost,
            .success("Recovered.")
        ])
        let service = TransformationService(provider: provider)

        let result = try await service.transform(
            sourceText: "hello",
            mode: mode,
            model: "test-model",
            timeoutSeconds: 1
        )

        XCTAssertEqual(result.outputText, "Recovered.")
        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 2)
    }

    func testMapsSecondNetworkConnectionLostToSemanticError() async throws {
        let provider = SequencedLLMProvider([
            .networkConnectionLost,
            .networkConnectionLost
        ])
        let service = TransformationService(provider: provider)

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected networkConnectionLost")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .networkConnectionLost)
        }

        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 2)
    }

    func testDoesNotRetryDifferentURLError() async throws {
        let provider = SequencedLLMProvider([
            .notConnectedToInternet,
            .success("Unexpected.")
        ])
        let service = TransformationService(provider: provider)

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected notConnectedToInternet")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }

        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 1)
    }

    func testDoesNotRetryNetworkConnectionLostCodeFromDifferentDomain() async throws {
        let provider = SequencedLLMProvider([
            .networkConnectionLostCodeFromDifferentDomain,
            .success("Unexpected.")
        ])
        let service = TransformationService(provider: provider)

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected custom-domain error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "TestDomain")
            XCTAssertEqual(error.code, URLError.networkConnectionLost.rawValue)
        }

        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 1)
    }

    func testPropagatesDifferentErrorFromSecondAttempt() async throws {
        let provider = SequencedLLMProvider([
            .networkConnectionLost,
            .badServerResponse
        ])
        let service = TransformationService(provider: provider)

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected badServerResponse")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        }

        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 2)
    }

    func testCancellationAfterFirstConnectionLossPreventsRetry() async throws {
        let provider = SequencedLLMProvider([
            .cancelThenNetworkConnectionLost,
            .success("Unexpected.")
        ])
        let service = TransformationService(provider: provider)

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 1
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        }

        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 1)
    }

    func testRetrySharesOriginalTimeoutBudget() async throws {
        let provider = SequencedLLMProvider([
            .delayedNetworkConnectionLost(nanoseconds: 300_000_000),
            .delayedSuccess("Unexpected.", nanoseconds: 300_000_000)
        ])
        let service = TransformationService(provider: provider)
        let started = Date()

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 0.5
            )
            XCTFail("Expected timeout")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .timeout)
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.8)
        let attempts = await provider.attemptCount()
        XCTAssertEqual(attempts, 2)
    }

    func testTimeoutReturnsPromptlyWhenProviderIgnoresCancellation() async throws {
        let service = TransformationService(provider: FakeLLMProvider(
            outputText: "Hello.",
            delayNanoseconds: 500_000_000,
            ignoresCancellation: true
        ))
        let started = Date()

        do {
            _ = try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 0.01
            )
            XCTFail("Expected timeout")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .timeout)
            XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
        }
    }

    func testParentCancellationThrowsCancellationError() async throws {
        let service = TransformationService(provider: FakeLLMProvider(
            outputText: "Hello.",
            delayNanoseconds: 500_000_000,
            ignoresCancellation: true
        ))
        let mode = mode
        let task = Task {
            try await service.transform(
                sourceText: "hello",
                mode: mode,
                model: "test-model",
                timeoutSeconds: 10
            )
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let started = Date()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
        }
    }

    func testStreamingProviderForwardsTrimmedPartialOutput() async throws {
        let service = TransformationService(provider: StreamingLLMProvider(
            partialOutputs: ["\n", "\nHel", "\nHello. "],
            outputText: "\nHello. "
        ))
        let partialOutputs = StreamedOutputRecorder()

        let result = try await service.transform(
            sourceText: "hello",
            mode: mode,
            model: "test-model",
            timeoutSeconds: 1,
            onPartialOutput: { partialOutputs.append($0) }
        )

        XCTAssertEqual(result.outputText, "Hello.")
        XCTAssertEqual(partialOutputs.values, ["Hel", "Hello."])
    }

    func testStreamingRequestFallsBackToCompleteResultForProvidersWithoutStreaming() async throws {
        let service = TransformationService(provider: FakeLLMProvider(outputText: "  Hello.  "))
        let partialOutputs = StreamedOutputRecorder()

        let result = try await service.transform(
            sourceText: "hello",
            mode: mode,
            model: "test-model",
            timeoutSeconds: 1,
            onPartialOutput: { partialOutputs.append($0) }
        )

        XCTAssertEqual(result.outputText, "Hello.")
        XCTAssertEqual(partialOutputs.values, [])
    }

    func testTransformWithoutPartialOutputDoesNotStream() async throws {
        let service = TransformationService(provider: StreamingLLMProvider(
            partialOutputs: ["Hel"],
            outputText: "Hello."
        ))

        let result = try await service.transform(
            sourceText: "hello",
            mode: mode,
            model: "test-model",
            timeoutSeconds: 1
        )

        XCTAssertEqual(result.providerMetadata["path"], "transform")
    }

    private var mode: PromptMode {
        PromptMode(
            id: "polish",
            name: "Polish",
            description: "Polish text",
            systemPrompt: "Improve the text.",
            shortcut: nil,
            participatesInAuto: true,
            autoRule: .englishHeavy,
            sortOrder: 1,
            isVisible: true
        )
    }
}

private struct FakeLLMProvider: LLMProvider {
    var outputText: String
    var delayNanoseconds: UInt64
    var ignoresCancellation: Bool

    init(
        outputText: String,
        delayNanoseconds: UInt64 = 0,
        ignoresCancellation: Bool = false
    ) {
        self.outputText = outputText
        self.delayNanoseconds = delayNanoseconds
        self.ignoresCancellation = ignoresCancellation
    }

    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        if delayNanoseconds > 0 {
            if ignoresCancellation {
                await sleepIgnoringCancellation(nanoseconds: delayNanoseconds)
            } else {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }

        return TransformationResult(
            outputText: outputText,
            providerMetadata: ["provider": "fake"],
            elapsedMilliseconds: 1
        )
    }

    private func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        let deadline = Date().addingTimeInterval(Double(nanoseconds) / 1_000_000_000)

        while Date() < deadline {
            do {
                try await Task.sleep(nanoseconds: 10_000_000)
            } catch {
                continue
            }
        }
    }
}

private struct StreamingLLMProvider: LLMProvider {
    var partialOutputs: [String]
    var outputText: String

    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        TransformationResult(outputText: outputText, providerMetadata: ["path": "transform"], elapsedMilliseconds: 1)
    }

    func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        for partialOutput in partialOutputs {
            onPartialOutput(partialOutput)
        }
        return TransformationResult(outputText: outputText, providerMetadata: ["path": "stream"], elapsedMilliseconds: 1)
    }
}

private final class StreamedOutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: String) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private actor SequencedLLMProvider: LLMProvider {
    enum Outcome: Sendable {
        case success(String)
        case networkConnectionLost
        case networkConnectionLostCodeFromDifferentDomain
        case notConnectedToInternet
        case badServerResponse
        case delayedNetworkConnectionLost(nanoseconds: UInt64)
        case delayedSuccess(String, nanoseconds: UInt64)
        case cancelThenNetworkConnectionLost
    }

    private var outcomes: [Outcome]
    private var attempts = 0

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        precondition(!outcomes.isEmpty, "Missing sequenced provider outcome")
        let outcome = outcomes.removeFirst()
        attempts += 1

        switch outcome {
        case .success(let outputText):
            return makeResult(outputText: outputText)
        case .networkConnectionLost:
            throw URLError(.networkConnectionLost)
        case .networkConnectionLostCodeFromDifferentDomain:
            throw NSError(
                domain: "TestDomain",
                code: URLError.networkConnectionLost.rawValue
            )
        case .notConnectedToInternet:
            throw URLError(.notConnectedToInternet)
        case .badServerResponse:
            throw URLError(.badServerResponse)
        case .delayedNetworkConnectionLost(let nanoseconds):
            try await Task.sleep(nanoseconds: nanoseconds)
            throw URLError(.networkConnectionLost)
        case .delayedSuccess(let outputText, let nanoseconds):
            try await Task.sleep(nanoseconds: nanoseconds)
            return makeResult(outputText: outputText)
        case .cancelThenNetworkConnectionLost:
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            throw URLError(.networkConnectionLost)
        }
    }

    func attemptCount() -> Int {
        attempts
    }

    private func makeResult(outputText: String) -> TransformationResult {
        TransformationResult(
            outputText: outputText,
            providerMetadata: ["provider": "sequenced"],
            elapsedMilliseconds: 1
        )
    }
}
