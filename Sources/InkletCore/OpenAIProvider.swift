import Foundation

public struct OpenAIProvider: LLMProvider {
    public struct RequestBody: Codable, Equatable {
        public struct InputMessage: Codable, Equatable {
            public var role: String
            public var content: String

            public init(role: String, content: String) {
                self.role = role
                self.content = content
            }
        }

        public var model: String
        public var input: [InputMessage]
        public var stream: Bool?

        public init(model: String, input: [InputMessage], stream: Bool? = nil) {
            self.model = model
            self.input = input
            self.stream = stream
        }
    }

    /// Accumulates the output text from Responses API server-sent events.
    public struct ResponseStreamParser: Sendable {
        private struct Event: Decodable {
            struct ErrorBody: Decodable {
                var message: String?
            }

            struct Response: Decodable {
                var output: [ResponseBody.OutputItem]?
                var error: ErrorBody?
            }

            var type: String
            var delta: String?
            var message: String?
            var response: Response?
        }

        public private(set) var outputText = ""

        public init() {}

        /// Consumes one stream line and returns the full output so far when the line added text.
        public mutating func consume(line: String) throws -> String? {
            guard line.hasPrefix("data:") else {
                return nil
            }

            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard payload != "[DONE]",
                  let data = payload.data(using: .utf8),
                  let event = try? JSONDecoder().decode(Event.self, from: data)
            else {
                return nil
            }

            switch event.type {
            case "response.output_text.delta":
                guard let delta = event.delta, !delta.isEmpty else {
                    return nil
                }
                outputText += delta
                return outputText
            case "response.completed":
                let completedText = ResponseBody(output: event.response?.output ?? []).outputText
                guard outputText.isEmpty, !completedText.isEmpty else {
                    return nil
                }
                outputText = completedText
                return outputText
            case "error":
                throw TransformationError.provider("OpenAI 请求失败：\(event.message ?? "HTTP unknown")")
            case "response.failed":
                throw TransformationError.provider(
                    "OpenAI 请求失败：\(event.response?.error?.message ?? "HTTP unknown")"
                )
            default:
                return nil
            }
        }

        public func finish() throws -> String {
            guard !outputText.isEmpty else {
                throw TransformationError.emptyResponse
            }
            return outputText
        }
    }

    private struct ResponseBody: Decodable {
        struct OutputItem: Decodable {
            var content: [ContentItem]?
        }

        struct ContentItem: Decodable {
            var type: String?
            var text: String?
        }

        var output: [OutputItem]

        var outputText: String {
            output
                .flatMap { $0.content ?? [] }
                .filter { $0.type == "output_text" }
                .compactMap(\.text)
                .joined()
        }
    }

    private struct ErrorResponseBody: Decodable {
        struct ErrorBody: Decodable {
            var message: String
        }

        var error: ErrorBody
    }

    private let apiKeyProvider: @Sendable () throws -> String
    private let endpoint: URL
    private let session: URLSession

    public init(
        apiKeyProvider: @escaping @Sendable () throws -> String,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.session = session
    }

    public func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        let urlRequest = try makeURLRequest(body: Self.makeRequestBody(for: request), timeoutSeconds: request.timeoutSeconds)

        let started = Date()
        let (data, response) = try await session.data(for: urlRequest)
        let elapsedMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransformationError.provider("OpenAI 请求失败：HTTP unknown")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TransformationError.provider(Self.providerErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let outputText = try Self.parseOutputText(from: data)
        return TransformationResult(
            outputText: outputText,
            providerMetadata: [
                "provider": "openai",
                "model": request.model
            ],
            elapsedMilliseconds: elapsedMilliseconds
        )
    }

    public func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        let urlRequest = try makeURLRequest(
            body: Self.makeRequestBody(for: request, stream: true),
            timeoutSeconds: request.timeoutSeconds
        )

        let started = Date()
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransformationError.provider("OpenAI 请求失败：HTTP unknown")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            throw TransformationError.provider(Self.providerErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        var parser = ResponseStreamParser()
        for try await line in bytes.lines {
            if let outputText = try parser.consume(line: line) {
                onPartialOutput(outputText)
            }
        }

        let outputText = try parser.finish()
        let elapsedMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)
        return TransformationResult(
            outputText: outputText,
            providerMetadata: [
                "provider": "openai",
                "model": request.model
            ],
            elapsedMilliseconds: elapsedMilliseconds
        )
    }

    public static func makeRequestBody(for request: TransformationRequest, stream: Bool = false) -> RequestBody {
        RequestBody(
            model: request.model,
            input: [
                RequestBody.InputMessage(role: "system", content: request.systemPrompt),
                RequestBody.InputMessage(role: "user", content: request.sourceText)
            ],
            stream: stream ? true : nil
        )
    }

    private func makeURLRequest(body: RequestBody, timeoutSeconds: TimeInterval) throws -> URLRequest {
        let apiKey = try apiKeyProvider()
        var urlRequest = URLRequest(url: endpoint, timeoutInterval: timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    public static func parseOutputText(from data: Data) throws -> String {
        let outputText = try JSONDecoder().decode(ResponseBody.self, from: data).outputText
        guard !outputText.isEmpty else {
            throw TransformationError.emptyResponse
        }
        return outputText
    }

    static func providerErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data) {
            return "OpenAI 请求失败：\(errorBody.error.message)"
        }

        return "OpenAI 请求失败：HTTP \(statusCode)"
    }
}
