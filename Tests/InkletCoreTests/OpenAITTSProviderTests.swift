import XCTest
@testable import InkletCore

final class OpenAITTSProviderTests: XCTestCase {
    func testBuildsAuthorizedTTSRequest() throws {
        let request = OpenAITTSRequest(
            input: "hello",
            model: "gpt-4o-mini-tts",
            voice: "alloy",
            speed: 1.25,
            timeoutSeconds: 8
        )

        let urlRequest = try OpenAITTSProvider.makeURLRequest(
            request,
            endpoint: URL(string: "https://api.openai.test/v1/audio/speech")!,
            apiKey: "tts-key"
        )

        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.timeoutInterval, 8)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer tts-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(urlRequest.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini-tts")
        XCTAssertEqual(json["voice"] as? String, "alloy")
        XCTAssertEqual(json["input"] as? String, "hello")
        XCTAssertEqual(json["format"] as? String, "mp3")
        XCTAssertEqual(json["speed"] as? Double, 1.25)
    }

    func testRejectsEmptyInput() throws {
        let request = OpenAITTSRequest(input: " \n", model: "gpt-4o-mini-tts", voice: "alloy", timeoutSeconds: 8)

        XCTAssertThrowsError(try OpenAITTSProvider.makeURLRequest(
            request,
            endpoint: URL(string: "https://api.openai.test/v1/audio/speech")!,
            apiKey: "tts-key"
        )) { error in
            XCTAssertEqual(error as? OpenAITTSError, .emptyInput)
        }
    }

    func testSpeakMapsProviderErrorWithoutLeakingAPIKey() async throws {
        MockTTSURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-key")
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = Data(#"{"error":{"message":"Invalid API key."}}"#.utf8)
            return (response, data)
        }
        defer { MockTTSURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockTTSURLProtocol.self]
        let provider = OpenAITTSProvider(
            apiKeyProvider: { "secret-key" },
            endpoint: URL(string: "https://api.openai.test/v1/audio/speech")!,
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await provider.speechAudio(OpenAITTSRequest(
                input: "hello",
                model: "gpt-4o-mini-tts",
                voice: "alloy",
                timeoutSeconds: 8
            ))
            XCTFail("Expected provider error")
        } catch {
            XCTAssertEqual(error as? OpenAITTSError, .provider("OpenAI pronunciation request failed: Invalid API key."))
            XCTAssertFalse(String(describing: error).contains("secret-key"))
        }
    }

    func testRejectsEmptyAudioResponse() async throws {
        MockTTSURLProtocol.handler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }
        defer { MockTTSURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockTTSURLProtocol.self]
        let provider = OpenAITTSProvider(
            apiKeyProvider: { "secret-key" },
            endpoint: URL(string: "https://api.openai.test/v1/audio/speech")!,
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await provider.speechAudio(OpenAITTSRequest(
                input: "hello",
                model: "gpt-4o-mini-tts",
                voice: "alloy",
                timeoutSeconds: 8
            ))
            XCTFail("Expected empty audio error")
        } catch {
            XCTAssertEqual(error as? OpenAITTSError, .emptyAudio)
        }
    }
}

private final class MockTTSURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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
