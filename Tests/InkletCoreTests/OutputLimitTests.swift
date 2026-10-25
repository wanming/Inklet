import Foundation
import XCTest
@testable import InkletCore

final class OutputLimitTests: XCTestCase {
    func testChatCompletionReportsAReplyCutOffAtTheLimit() {
        let truncated = Data(#"{"choices":[{"message":{"content":"Partial"},"finish_reason":"length"}]}"#.utf8)
        let complete = Data(#"{"choices":[{"message":{"content":"Done"},"finish_reason":"stop"}]}"#.utf8)

        XCTAssertTrue(ChatCompletionProvider.outputWasTruncated(in: truncated))
        XCTAssertFalse(ChatCompletionProvider.outputWasTruncated(in: complete))
    }

    func testChatCompletionStreamReportsAReplyCutOffAtTheLimit() {
        var parser = ChatCompletionProvider.StreamParser()
        _ = parser.consume(line: #"data: {"choices":[{"delta":{"content":"Partial"},"finish_reason":null}]}"#)
        XCTAssertFalse(parser.wasTruncated)

        _ = parser.consume(line: #"data: {"choices":[{"delta":{},"finish_reason":"length"}]}"#)
        _ = parser.consume(line: "data: [DONE]")

        XCTAssertTrue(parser.wasTruncated)
        XCTAssertEqual(parser.outputText, "Partial")
    }

    func testOpenAIReportsAnIncompleteResponseAtTheOutputLimit() throws {
        let truncated = Data(#"""
        {"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},
         "output":[{"content":[{"type":"output_text","text":"Partial"}]}]}
        """#.utf8)
        let filtered = Data(#"""
        {"status":"incomplete","incomplete_details":{"reason":"content_filter"},
         "output":[{"content":[{"type":"output_text","text":"Partial"}]}]}
        """#.utf8)

        XCTAssertTrue(OpenAIProvider.outputWasTruncated(in: truncated))
        XCTAssertFalse(OpenAIProvider.outputWasTruncated(in: filtered))
        XCTAssertEqual(try OpenAIProvider.parseOutputText(from: truncated), "Partial")
    }

    func testOpenAIStreamReportsAnIncompleteResponseAtTheOutputLimit() throws {
        var parser = OpenAIProvider.ResponseStreamParser()
        _ = try parser.consume(line: #"data: {"type":"response.output_text.delta","delta":"Partial"}"#)
        _ = try parser.consume(line: #"data: {"type":"response.incomplete","response":{"incomplete_details":{"reason":"max_output_tokens"}}}"#)

        XCTAssertTrue(parser.wasTruncated)
        XCTAssertEqual(try parser.finish(), "Partial")
    }

    func testAnthropicAndGeminiReportARepliesCutOffAtTheLimit() {
        XCTAssertTrue(AnthropicProvider.outputWasTruncated(in: Data(
            #"{"content":[{"type":"text","text":"Partial"}],"stop_reason":"max_tokens"}"#.utf8
        )))
        XCTAssertFalse(AnthropicProvider.outputWasTruncated(in: Data(
            #"{"content":[{"type":"text","text":"Done"}],"stop_reason":"end_turn"}"#.utf8
        )))
        XCTAssertTrue(GeminiProvider.outputWasTruncated(in: Data(
            #"{"candidates":[{"content":{"parts":[{"text":"Partial"}]},"finishReason":"MAX_TOKENS"}]}"#.utf8
        )))
        XCTAssertFalse(GeminiProvider.outputWasTruncated(in: Data(
            #"{"candidates":[{"content":{"parts":[{"text":"Done"}]},"finishReason":"STOP"}]}"#.utf8
        )))
    }

    func testRecognizesContextOverflowErrors() {
        let llamaServer = #"{"error":{"code":400,"message":"the request exceeds the available context size, try increasing it","type":"exceed_context_size_error"}}"#
        let openAI = #"{"error":{"message":"This model's maximum context length is 128000 tokens.","code":"context_length_exceeded"}}"#
        let anthropic = #"{"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long: 250000 tokens > 200000 maximum"}}"#
        let lmStudio = #"{"error":"Trying to keep the first 9000 tokens when context the overflows. However, the model is loaded with context length of only 4096 tokens, which is not enough."}"#
        let unrelated = #"{"error":{"message":"Incorrect API key provided."}}"#
        let mentionsContext = #"{"error":{"message":"Invalid context size parameter for this endpoint."}}"#

        XCTAssertTrue(ContextLimitError.matches(responseBody: Data(llamaServer.utf8)))
        XCTAssertTrue(ContextLimitError.matches(responseBody: Data(openAI.utf8)))
        XCTAssertTrue(ContextLimitError.matches(responseBody: Data(anthropic.utf8)))
        XCTAssertTrue(ContextLimitError.matches(responseBody: Data(lmStudio.utf8)))
        XCTAssertFalse(ContextLimitError.matches(responseBody: Data(unrelated.utf8)))
        XCTAssertFalse(ContextLimitError.matches(responseBody: Data(mentionsContext.utf8)))
    }

    func testAnthropicOutputCapFitsEachModel() {
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-haiku-4-5"), 32000)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-opus-4-20250514"), 32000)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-3-7-sonnet-20250219"), 32000)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-3-5-haiku-latest"), 8192)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-3-5-sonnet-20240620"), 8192)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-3-haiku-20240307"), 4096)
        XCTAssertEqual(AnthropicProvider.maxOutputTokens(forModel: "claude-3-opus-20240229"), 4096)
    }

    func testCutOffTranslationIsShownButNotCached() async throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let service = CachedSelectionTranslationService(
            service: SelectionTranslationService(provider: TruncatingProvider()),
            cache: JSONSelectionTranslationCache(fileURL: cacheURL)
        )

        let first = try await service.translation(
            sourceText: "A long text",
            targetLanguageName: "Chinese",
            systemPrompt: "Translate.",
            model: "test-model",
            providerID: "test",
            timeoutSeconds: 1
        )
        XCTAssertEqual(first, SelectionTranslation(text: "Partial", wasTruncated: true))

        let cache = JSONSelectionTranslationCache(fileURL: cacheURL)
        let key = SelectionTranslationCacheKey(
            sourceText: "A long text",
            targetLanguageName: "Chinese",
            systemPrompt: "Translate.",
            model: "test-model",
            providerID: "test"
        )
        XCTAssertNil(try? cache.translation(for: key, now: Date()))
    }

    func testServiceKeepsTheTruncationFlag() async throws {
        let service = TransformationService(provider: TruncatingProvider())

        let result = try await service.transform(
            sourceText: "A long text",
            mode: PromptMode(
                id: "polish",
                name: "Polish",
                description: "Polish text",
                systemPrompt: "Improve the text.",
                shortcut: nil,
                participatesInAuto: true,
                autoRule: .englishHeavy,
                sortOrder: 1,
                isVisible: true
            ),
            model: "test-model",
            timeoutSeconds: 1
        )

        XCTAssertEqual(result.outputText, "Partial")
        XCTAssertTrue(result.wasTruncated)
    }
}

private struct TruncatingProvider: LLMProvider {
    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        TransformationResult(outputText: " Partial ", providerMetadata: [:], elapsedMilliseconds: 1, wasTruncated: true)
    }
}
