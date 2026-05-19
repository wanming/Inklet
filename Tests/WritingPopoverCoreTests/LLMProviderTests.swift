import XCTest
@testable import WritingPopoverCore

final class LLMProviderTests: XCTestCase {
    func testProviderPresetCoversMainstreamProviders() {
        XCTAssertEqual(
            LLMProviderPreset.all.map(\.id),
            [
                "openai",
                "anthropic",
                "gemini",
                "deepseek",
                "xai",
                "groq",
                "mistral",
                "openrouter",
                "perplexity",
                "together",
                "cerebras"
            ]
        )
    }

    func testChatCompletionBuildsOpenAICompatibleRequest() {
        let body = ChatCompletionProvider.makeRequestBody(for: request)

        XCTAssertEqual(body.model, "test-model")
        XCTAssertEqual(body.temperature, 0.2)
        XCTAssertEqual(body.messages.map(\.role), ["system", "user"])
        XCTAssertEqual(body.messages.map(\.content), ["Rewrite clearly.", "Hello"])
    }

    func testChatCompletionParsesResponseText() throws {
        let json = #"{"choices":[{"message":{"content":"Hi there."}}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertEqual(try ChatCompletionProvider.parseOutputText(from: data), "Hi there.")
    }

    func testAnthropicBuildsMessagesRequest() {
        let body = AnthropicProvider.makeRequestBody(for: request)

        XCTAssertEqual(body.model, "test-model")
        XCTAssertEqual(body.system, "Rewrite clearly.")
        XCTAssertEqual(body.messages.first?.role, "user")
        XCTAssertEqual(body.messages.first?.content.first?.text, "Hello")
    }

    func testAnthropicParsesResponseText() throws {
        let json = #"{"content":[{"type":"text","text":"Hi there."}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertEqual(try AnthropicProvider.parseOutputText(from: data), "Hi there.")
    }

    func testGeminiBuildsGenerateContentRequest() {
        let body = GeminiProvider.makeRequestBody(for: request)

        XCTAssertEqual(body.systemInstruction.parts.first?.text, "Rewrite clearly.")
        XCTAssertEqual(body.contents.first?.role, "user")
        XCTAssertEqual(body.contents.first?.parts.first?.text, "Hello")
        XCTAssertEqual(body.generationConfig.temperature, 0.2)
    }

    func testGeminiParsesResponseText() throws {
        let json = #"{"candidates":[{"content":{"parts":[{"text":"Hi there."}]}}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertEqual(try GeminiProvider.parseOutputText(from: data), "Hi there.")
    }

    private var request: TransformationRequest {
        TransformationRequest(
            sourceText: "Hello",
            systemPrompt: "Rewrite clearly.",
            modeID: "polish",
            modeName: "Polish",
            model: "test-model",
            temperature: 0.2,
            timeoutSeconds: 10
        )
    }
}
