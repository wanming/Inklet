import Foundation

public struct ChatCompletionProvider: LLMProvider {
    public struct RequestBody: Codable, Equatable {
        public struct Message: Codable, Equatable {
            public var role: String
            public var content: String
        }

        public var model: String
        public var messages: [Message]
        /// Sent as "none" to local servers so small reasoning models answer directly.
        public var reasoningEffort: String?

        private enum CodingKeys: String, CodingKey {
            case model
            case messages
            case reasoningEffort = "reasoning_effort"
        }
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String?
            }

            var message: Message?
        }

        var choices: [Choice]
    }

    private struct ErrorResponseBody: Decodable {
        struct ErrorBody: Decodable {
            var message: String?
        }

        var error: ErrorBody
    }

    private let name: String
    private let apiKeyProvider: @Sendable () throws -> String
    private let endpoint: URL
    private let runsLocally: Bool
    private let session: URLSession

    public init(
        name: String,
        apiKeyProvider: @escaping @Sendable () throws -> String,
        endpoint: URL,
        runsLocally: Bool = false,
        session: URLSession = .shared
    ) {
        self.name = name
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.runsLocally = runsLocally
        self.session = session
    }

    public func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        let apiKey = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyData = try JSONEncoder().encode(Self.makeRequestBody(for: request, disablesReasoning: runsLocally))

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = "POST"
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = bodyData

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where runsLocally && error.code == .cannotConnectToHost {
            throw LocalModelError.serverUnreachable(providerName: name)
        }
        let elapsedMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransformationError.provider("\(name) 请求失败：HTTP unknown")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TransformationError.provider(providerErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let outputText = try Self.parseOutputText(from: data)
        return TransformationResult(
            outputText: outputText,
            providerMetadata: [
                "provider": name,
                "model": request.model
            ],
            elapsedMilliseconds: elapsedMilliseconds
        )
    }

    public static func makeRequestBody(
        for request: TransformationRequest,
        disablesReasoning: Bool = false
    ) -> RequestBody {
        RequestBody(
            model: request.model,
            messages: [
                RequestBody.Message(role: "system", content: request.systemPrompt),
                RequestBody.Message(role: "user", content: request.sourceText)
            ],
            reasoningEffort: disablesReasoning ? "none" : nil
        )
    }

    public static func parseOutputText(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(ResponseBody.self, from: data)
        let outputText = removingThinkingBlock(from: response.choices.compactMap(\.message?.content).joined())
        guard !outputText.isEmpty else {
            throw TransformationError.emptyResponse
        }
        return outputText
    }

    /// Some local servers ignore `reasoning_effort` and return the model's thinking inline.
    static func removingThinkingBlock(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<think>") else {
            return text
        }
        guard let closingRange = trimmed.range(of: "</think>") else {
            return ""
        }
        return String(trimmed[closingRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func providerErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data),
           let message = errorBody.error.message {
            return "\(name) 请求失败：\(message)"
        }

        return "\(name) 请求失败：HTTP \(statusCode)"
    }
}
