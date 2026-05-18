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

    func testParsesOutputTextWhenResponseContainsNonTextOutputItems() throws {
        let json = """
        {
          "output": [
            {
              "type": "web_search_call",
              "status": "completed"
            },
            {
              "type": "message",
              "content": [
                {
                  "type": "refusal",
                  "text": "Ignored."
                },
                {
                  "type": "output_text",
                  "text": "Kept."
                }
              ]
            }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let outputText = try OpenAIProvider.parseOutputText(from: data)

        XCTAssertEqual(outputText, "Kept.")
    }

    func testParseOutputTextThrowsEmptyResponseWhenNoOutputTextExists() throws {
        let json = """
        {
          "output": [
            {
              "type": "web_search_call",
              "status": "completed"
            },
            {
              "type": "message",
              "content": [
                {
                  "type": "refusal",
                  "text": "Not usable output."
                }
              ]
            }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertThrowsError(try OpenAIProvider.parseOutputText(from: data)) { error in
            XCTAssertEqual(error as? TransformationError, .emptyResponse)
        }
    }

    func testTransformPostsAuthorizedRequestAndMapsOpenAIErrorPayload() async throws {
        MockOpenAIURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = try XCTUnwrap("""
            {
              "error": {
                "message": "Rate limit exceeded."
              }
            }
            """.data(using: .utf8))
            return (response, data)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockOpenAIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let provider = OpenAIProvider(
            apiKeyProvider: { "test-api-key" },
            endpoint: URL(string: "https://api.openai.test/v1/responses")!,
            session: session
        )
        let request = TransformationRequest(
            sourceText: "Make this clearer.",
            systemPrompt: "Rewrite in polished English.",
            modeID: "polish",
            modeName: "Polish",
            model: "gpt-4.1-mini",
            temperature: 0.2,
            timeoutSeconds: 10
        )

        do {
            _ = try await provider.transform(request)
            XCTFail("Expected transform to throw")
        } catch {
            XCTAssertEqual(error as? TransformationError, .provider("OpenAI 请求失败：Rate limit exceeded."))
        }

        MockOpenAIURLProtocol.handler = nil
    }
}

private final class MockOpenAIURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
