import Foundation

/// Failures specific to models that run on this Mac. The app maps each case to localized copy.
public enum LocalModelError: Error, Equatable, Sendable {
    /// Ollama, LM Studio, or another local server is not listening at its endpoint.
    case serverUnreachable(providerName: String)
    /// This build of Inklet does not include the built-in engine.
    case engineMissing
    case unknownModel(String)
    case modelNotInstalled(modelName: String)
    case engineFailedToStart
    case downloadFailed(statusCode: Int)
    case downloadIncomplete
    case checksumMismatch
}

/// Reads the model IDs a local OpenAI-compatible server offers at `GET /v1/models`.
public enum LocalModelListClient {
    private struct ResponseBody: Decodable {
        struct Model: Decodable {
            var id: String
        }

        var data: [Model]
    }

    public static func modelIDs(from data: Data) throws -> [String] {
        let response = try JSONDecoder().decode(ResponseBody.self, from: data)
        var seen = Set<String>()
        return response.data.map(\.id).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func fetchModelIDs(
        from endpoint: URL,
        providerName: String,
        session: URLSession = .shared
    ) async throws -> [String] {
        let request = URLRequest(url: endpoint, timeoutInterval: 5)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where isUnreachable(error) {
            throw LocalModelError.serverUnreachable(providerName: providerName)
        }
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw LocalModelError.serverUnreachable(providerName: providerName)
        }
        return try modelIDs(from: data)
    }

    static func isUnreachable(_ error: URLError) -> Bool {
        [.cannotConnectToHost, .cannotFindHost, .timedOut, .networkConnectionLost, .notConnectedToInternet]
            .contains(error.code)
    }
}
