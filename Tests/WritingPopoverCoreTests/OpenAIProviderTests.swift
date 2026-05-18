import XCTest
@testable import WritingPopoverCore

final class OpenAIProviderTests: XCTestCase {
    func testBuildsResponsesAPIRequest() {
        let request = TransformationRequest(
            sourceText: "Make this clearer.",
            systemPrompt: "Rewrite in polished English.",
            modeID: "polish",
            modeName: "Polish",
            model: "gpt-4.1-mini",
            temperature: 0.2,
            timeoutSeconds: 10
        )

        let body = OpenAIProvider.makeRequestBody(for: request)

        XCTAssertEqual(body.model, "gpt-4.1-mini")
        XCTAssertEqual(body.temperature, 0.2)
        XCTAssertTrue(body.input.contains(.init(role: "system", content: "Rewrite in polished English.")))
        XCTAssertTrue(body.input.contains(.init(role: "user", content: "Make this clearer.")))
    }

    func testParsesOutputTextFromResponse() throws {
        let json = """
        {
          "output": [
            {
              "content": [
                {
                  "type": "output_text",
                  "text": "Hello."
                }
              ]
            }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let outputText = try OpenAIProvider.parseOutputText(from: data)

        XCTAssertEqual(outputText, "Hello.")
    }
}
