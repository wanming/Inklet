import Foundation

public enum LLMProviderFactory {
    public static func provider(
        for preset: LLMProviderPreset,
        apiKeyProvider: @escaping @Sendable () throws -> String
    ) -> any LLMProvider {
        switch preset.kind {
        case .openAIResponses:
            return OpenAIProvider(apiKeyProvider: apiKeyProvider, endpoint: preset.endpoint)
        case .openAICompatibleChat where preset.isBuiltIn:
            return BuiltInModelProvider()
        case .openAICompatibleChat:
            return ChatCompletionProvider(
                name: preset.name,
                apiKeyProvider: apiKeyProvider,
                endpoint: preset.endpoint,
                runsLocally: preset.runsLocally
            )
        case .anthropicMessages:
            return AnthropicProvider(apiKeyProvider: apiKeyProvider, endpoint: preset.endpoint)
        case .geminiGenerateContent:
            return GeminiProvider(apiKeyProvider: apiKeyProvider, baseURL: preset.endpoint)
        }
    }
}
