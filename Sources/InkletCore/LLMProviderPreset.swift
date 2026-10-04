import Foundation

public struct LLMProviderPreset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var defaultModel: String
    public var apiKeyPlaceholder: String
    public var endpoint: URL

    public init(
        id: String,
        name: String,
        defaultModel: String,
        apiKeyPlaceholder: String,
        endpoint: URL
    ) {
        self.id = id
        self.name = name
        self.defaultModel = defaultModel
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.endpoint = endpoint
    }

    public static let openAI = LLMProviderPreset(
        id: "openai",
        name: "OpenAI",
        defaultModel: "gpt-5.6-luna",
        apiKeyPlaceholder: "sk-...",
        endpoint: URL(string: "https://api.openai.com/v1/responses")!
    )
}
