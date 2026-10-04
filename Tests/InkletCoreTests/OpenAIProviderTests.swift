import XCTest
@testable import InkletCore

final class OpenAIProviderTests: XCTestCase {
    func testBuildsResponsesAPIRequestWithoutTemperature() throws {
        let request = TransformationRequest(
            sourceText: "Make this clearer.",
            systemPrompt: "Rewrite in polished English.",
            modeID: "polish",
            modeName: "Polish",
            model: "gpt-4.1-mini",
            timeoutSeconds: 10
        )

        let body = OpenAIProvider.makeRequestBody(for: request)
        let json = try encodedJSONObject(body)
        let input = try XCTUnwrap(json["input"] as? [[String: Any]])

        XCTAssertNil(json["temperature"])
        XCTAssertNil(json["stream"])
        XCTAssertEqual(json["model"] as? String, "gpt-4.1-mini")
        XCTAssertTrue(input.contains {
            $0["role"] as? String == "system" && $0["content"] as? String == "Rewrite in polished English."
        })
        XCTAssertTrue(input.contains {
            $0["role"] as? String == "user" && $0["content"] as? String == "Make this clearer."
        })
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

    func testStreamingRequestBodyAsksForServerSentEvents() throws {
        let body = OpenAIProvider.makeRequestBody(for: request(), stream: true)
        let json = try encodedJSONObject(body)

        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["model"] as? String, "gpt-4.1-mini")
    }

    func testStreamParserAccumulatesTextDeltasAndIgnoresOtherLines() throws {
        var parser = OpenAIProvider.ResponseStreamParser()

        XCTAssertNil(try parser.consume(line: "event: response.output_text.delta"))
        XCTAssertNil(try parser.consume(line: #"data: {"type":"response.created","response":{}}"#))
        XCTAssertEqual(try parser.consume(line: #"data: {"type":"response.output_text.delta","delta":"Hel"}"#), "Hel")
        XCTAssertNil(try parser.consume(line: ": keep-alive"))
        XCTAssertNil(try parser.consume(line: "data: not json"))
        XCTAssertEqual(try parser.consume(line: #"data: {"type":"response.output_text.delta","delta":"lo."}"#), "Hello.")
        XCTAssertNil(try parser.consume(line: #"data: {"type":"response.completed","response":{"output":[{"content":[{"type":"output_text","text":"Hello."}]}]}}"#))
        XCTAssertNil(try parser.consume(line: "data: [DONE]"))

        XCTAssertEqual(try parser.finish(), "Hello.")
    }

    func testStreamParserFallsBackToCompletedResponseWithoutDeltas() throws {
        var parser = OpenAIProvider.ResponseStreamParser()

        let output = try parser.consume(
            line: #"data: {"type":"response.completed","response":{"output":[{"content":[{"type":"output_text","text":"Done."}]}]}}"#
        )

        XCTAssertEqual(output, "Done.")
        XCTAssertEqual(try parser.finish(), "Done.")
    }

    func testStreamParserThrowsEmptyResponseWithoutText() {
        let parser = OpenAIProvider.ResponseStreamParser()

        XCTAssertThrowsError(try parser.finish()) { error in
            XCTAssertEqual(error as? TransformationError, .emptyResponse)
        }
    }

    func testStreamParserMapsErrorAndFailedEvents() {
        var parser = OpenAIProvider.ResponseStreamParser()
        XCTAssertThrowsError(try parser.consume(line: #"data: {"type":"error","message":"Overloaded."}"#)) { error in
            XCTAssertEqual(error as? TransformationError, .provider("OpenAI 请求失败：Overloaded."))
        }

        var failedParser = OpenAIProvider.ResponseStreamParser()
        XCTAssertThrowsError(
            try failedParser.consume(line: #"data: {"type":"response.failed","response":{"error":{"message":"Model failed."}}}"#)
        ) { error in
            XCTAssertEqual(error as? TransformationError, .provider("OpenAI 请求失败：Model failed."))
        }
    }

    func testStreamTransformReportsPartialOutputAndReturnsFullText() async throws {
        MockOpenAIURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            ))
            let data = try XCTUnwrap("""
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"Hel"}

            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"lo."}

            event: response.completed
            data: {"type":"response.completed","response":{"output":[]}}

            """.data(using: .utf8))
            return (response, data)
        }
        defer { MockOpenAIURLProtocol.handler = nil }
        let partialOutputs = PartialOutputRecorder()

        let result = try await makeMockedProvider().streamTransform(request()) { partialOutput in
            partialOutputs.append(partialOutput)
        }

        XCTAssertEqual(result.outputText, "Hello.")
        XCTAssertEqual(result.providerMetadata["provider"], "openai")
        XCTAssertEqual(partialOutputs.values, ["Hel", "Hello."])
    }

    func testStreamTransformMapsOpenAIErrorPayload() async throws {
        MockOpenAIURLProtocol.handler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = try XCTUnwrap(#"{"error":{"message":"Invalid API key."}}"#.data(using: .utf8))
            return (response, data)
        }
        defer { MockOpenAIURLProtocol.handler = nil }

        do {
            _ = try await makeMockedProvider().streamTransform(request()) { _ in }
            XCTFail("Expected streamTransform to throw")
        } catch {
            XCTAssertEqual(error as? TransformationError, .provider("OpenAI 请求失败：Invalid API key."))
        }
    }

    private func request() -> TransformationRequest {
        TransformationRequest(
            sourceText: "Make this clearer.",
            systemPrompt: "Rewrite in polished English.",
            modeID: "polish",
            modeName: "Polish",
            model: "gpt-4.1-mini",
            timeoutSeconds: 10
        )
    }

    private func makeMockedProvider() -> OpenAIProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockOpenAIURLProtocol.self]
        return OpenAIProvider(
            apiKeyProvider: { "test-api-key" },
            endpoint: URL(string: "https://api.openai.test/v1/responses")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class PartialOutputRecorder: @unchecked Sendable {
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
