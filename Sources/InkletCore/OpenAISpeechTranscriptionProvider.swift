import Foundation

public struct OpenAISpeechTranscriptionProvider: SpeechTranscriptionProvider {
    private struct JSONTextResponse: Decodable {
        var text: String
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
        endpoint: URL = URL(string: VoiceInputConfig.defaultSpeechEndpoint)!,
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.session = session
    }

    public func transcribe(_ request: SpeechTranscriptionRequest) async throws -> SpeechTranscriptionResult {
        let apiKey = try apiKeyProvider()
        let urlRequest = try Self.makeURLRequest(
            request,
            endpoint: endpoint,
            apiKey: apiKey,
            boundary: "InkletBoundary-\(UUID().uuidString)"
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechTranscriptionError.provider("OpenAI speech request failed: HTTP unknown")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SpeechTranscriptionError.provider(Self.providerErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let text = try Self.parseTranscriptionText(from: data)
        return SpeechTranscriptionResult(
            text: text,
            providerMetadata: [
                "provider": "openai-speech",
                "model": request.model
            ]
        )
    }

    public static func makeURLRequest(
        _ request: SpeechTranscriptionRequest,
        endpoint: URL,
        apiKey: String,
        boundary: String
    ) throws -> URLRequest {
        let audioData = try Data(contentsOf: request.audioFileURL)
        guard !audioData.isEmpty else {
            throw SpeechTranscriptionError.emptyAudio
        }

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = makeMultipartBody(
            audioData: audioData,
            filename: request.audioFileURL.lastPathComponent,
            model: request.model,
            boundary: boundary
        )
        return urlRequest
    }

    public static func parseTranscriptionText(from data: Data) throws -> String {
        let text: String
        if let jsonResponse = try? JSONDecoder().decode(JSONTextResponse.self, from: data) {
            text = jsonResponse.text
        } else {
            text = String(data: data, encoding: .utf8) ?? ""
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw SpeechTranscriptionError.emptyResponse
        }
        return trimmedText
    }

    private static func makeMultipartBody(
        audioData: Data,
        filename: String,
        model: String,
        boundary: String
    ) -> Data {
        var body = Data()
        appendField(name: "model", value: model, boundary: boundary, to: &body)
        appendFile(
            name: "file",
            filename: filename,
            contentType: "audio/m4a",
            data: audioData,
            boundary: boundary,
            to: &body
        )
        body.append("--\(boundary)--\r\n")
        return body
    }

    private static func appendField(name: String, value: String, boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    private static func appendFile(
        name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String,
        to body: inout Data
    ) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")
    }

    private static func providerErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorBody = try? JSONDecoder().decode(ErrorResponseBody.self, from: data) {
            return "OpenAI speech request failed: \(errorBody.error.message)"
        }

        return "OpenAI speech request failed: HTTP \(statusCode)"
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
