import Foundation

public struct OpenAITTSRequest: Equatable, Sendable {
    public var input: String
    public var model: String
    public var voice: String
    public var timeoutSeconds: TimeInterval

    public init(
        input: String,
        model: String = "gpt-4o-mini-tts",
        voice: String = "alloy",
        timeoutSeconds: TimeInterval
    ) {
        self.input = input
        self.model = model
        self.voice = voice
        self.timeoutSeconds = timeoutSeconds
    }
}

public enum OpenAITTSError: Error, Equatable, LocalizedError, Sendable {
    case emptyInput
    case emptyAudio
    case provider(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Pronunciation text is empty."
        case .emptyAudio:
            "OpenAI pronunciation returned no audio."
        case .provider(let message):
            message
        }
    }
}

public struct OpenAITTSProvider: Sendable {
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
        endpoint: URL = URL(string: "https://api.openai.com/v1/audio/speech")!,
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.session = session
    }

    public func speechAudio(_ request: OpenAITTSRequest) async throws -> Data {
        let apiKey = try apiKeyProvider()
        let urlRequest = try Self.makeURLRequest(request, endpoint: endpoint, apiKey: apiKey)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITTSError.provider("OpenAI pronunciation request failed: HTTP unknown")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAITTSError.provider(Self.providerErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }
        guard !data.isEmpty else {
            throw OpenAITTSError.emptyAudio
        }
        return data
    }

    public static func makeURLRequest(
        _ request: OpenAITTSRequest,
        endpoint: URL,
        apiKey: String
    ) throws -> URLRequest {
        let trimmedInput = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw OpenAITTSError.emptyInput
        }

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "voice": request.voice,
            "input": trimmedInput,
            "format": "mp3"
        ])
        return urlRequest
    }

    private static func providerErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data) {
            return "OpenAI pronunciation request failed: \(errorBody.error.message)"
        }

        return "OpenAI pronunciation request failed: HTTP \(statusCode)"
    }
}
