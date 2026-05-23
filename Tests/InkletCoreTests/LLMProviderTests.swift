import XCTest
@testable import InkletCore

final class LLMProviderTests: XCTestCase {
    func testProviderPresetCoversMainstreamProviders() {
        XCTAssertEqual(
            LLMProviderPreset.all.map(\.id),
            [
                "openai",
                "anthropic",
                "gemini",
                "deepseek",
                "qwen",
                "moonshot",
                "zhipu",
                "minimax",
                "siliconflow",
                "volcengine",
                "tencent-hunyuan",
                "baichuan",
                "lingyiwanwu",
                "xai",
                "groq",
                "mistral",
                "openrouter",
                "perplexity",
                "together",
                "cerebras",
                "custom-openai-compatible"
            ]
        )
    }

    func testProviderDefaultsUseCurrentFastModels() {
        let defaults = Dictionary(uniqueKeysWithValues: LLMProviderPreset.all.map { ($0.id, $0.defaultModel) })

        XCTAssertEqual(defaults["openai"], "gpt-5.4-mini")
        XCTAssertEqual(defaults["anthropic"], "claude-haiku-4-5")
        XCTAssertEqual(defaults["gemini"], "gemini-flash-latest")
        XCTAssertEqual(defaults["deepseek"], "deepseek-v4-flash")
        XCTAssertEqual(defaults["qwen"], "qwen3.6-plus")
        XCTAssertEqual(defaults["minimax"], "MiniMax-M2.7-highspeed")
        XCTAssertEqual(defaults["groq"], "meta-llama/llama-4-scout-17b-16e-instruct")
        XCTAssertEqual(defaults["openrouter"], "openai/gpt-5.4-mini")
        XCTAssertEqual(defaults["custom-openai-compatible"], "gpt-5-mini")
        XCTAssertTrue(LLMProviderPreset.all.allSatisfy { !$0.defaultModel.isEmpty })
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
