import XCTest
@testable import WritingPopoverCore

final class TransformationServiceTests: XCTestCase {
    func testSuccessfulProviderReturnsTrimmedResult() async throws {
        let service = TransformationService(provider: FakeLLMProvider(outputText: "  Hello.  "))

        let result = try await service.transform(
            sourceText: "  hello  ",
            mode: mode,
            model: "test-model",
            temperature: 0.2,
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
                temperature: 0.2,
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
                temperature: 0.2,
                timeoutSeconds: 0.01
            )
            XCTFail("Expected timeout")
        } catch let error as TransformationError {
            XCTAssertEqual(error, .timeout)
        }
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

    init(outputText: String, delayNanoseconds: UInt64 = 0) {
        self.outputText = outputText
        self.delayNanoseconds = delayNanoseconds
    }

    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        return TransformationResult(
            outputText: outputText,
            providerMetadata: ["provider": "fake"],
            elapsedMilliseconds: 1
        )
    }
}
