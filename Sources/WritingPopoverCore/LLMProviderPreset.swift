import Foundation

public enum LLMProviderKind: String, Codable, Sendable {
    case openAIResponses
    case openAICompatibleChat
    case anthropicMessages
    case geminiGenerateContent
}

public struct LLMProviderPreset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var defaultModel: String
    public var apiKeyPlaceholder: String
    public var keychainService: String
    public var kind: LLMProviderKind
    public var endpoint: URL

    public init(
        id: String,
        name: String,
        defaultModel: String,
        apiKeyPlaceholder: String,
        keychainService: String,
        kind: LLMProviderKind,
        endpoint: URL
    ) {
        self.id = id
        self.name = name
        self.defaultModel = defaultModel
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.keychainService = keychainService
        self.kind = kind
        self.endpoint = endpoint
    }

    public static let openAI = LLMProviderPreset(
        id: "openai",
        name: "OpenAI",
        defaultModel: "gpt-4.1-mini",
        apiKeyPlaceholder: "sk-...",
        keychainService: KeychainStore.defaultService,
        kind: .openAIResponses,
        endpoint: URL(string: "https://api.openai.com/v1/responses")!
    )

    public static let all: [LLMProviderPreset] = [
        .openAI,
        LLMProviderPreset(
            id: "anthropic",
            name: "Anthropic",
            defaultModel: "claude-3-5-haiku-latest",
            apiKeyPlaceholder: "sk-ant-...",
            keychainService: "Fluenta.Anthropic",
            kind: .anthropicMessages,
            endpoint: URL(string: "https://api.anthropic.com/v1/messages")!
        ),
        LLMProviderPreset(
            id: "gemini",
            name: "Google Gemini",
            defaultModel: "gemini-1.5-flash",
            apiKeyPlaceholder: "AIza...",
            keychainService: "Fluenta.Gemini",
            kind: .geminiGenerateContent,
            endpoint: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        ),
        openAICompatible(
            id: "deepseek",
            name: "DeepSeek",
            defaultModel: "deepseek-chat",
            placeholder: "sk-...",
            service: "Fluenta.DeepSeek",
            endpoint: "https://api.deepseek.com/chat/completions"
        ),
        openAICompatible(
            id: "xai",
            name: "xAI",
            defaultModel: "grok-3-mini",
            placeholder: "xai-...",
            service: "Fluenta.xAI",
            endpoint: "https://api.x.ai/v1/chat/completions"
        ),
        openAICompatible(
            id: "groq",
            name: "Groq",
            defaultModel: "llama-3.1-8b-instant",
            placeholder: "gsk_...",
            service: "Fluenta.Groq",
            endpoint: "https://api.groq.com/openai/v1/chat/completions"
        ),
        openAICompatible(
            id: "mistral",
            name: "Mistral",
            defaultModel: "mistral-small-latest",
            placeholder: "...",
            service: "Fluenta.Mistral",
            endpoint: "https://api.mistral.ai/v1/chat/completions"
        ),
        openAICompatible(
            id: "openrouter",
            name: "OpenRouter",
            defaultModel: "openai/gpt-4.1-mini",
            placeholder: "sk-or-...",
            service: "Fluenta.OpenRouter",
            endpoint: "https://openrouter.ai/api/v1/chat/completions"
        ),
        openAICompatible(
            id: "perplexity",
            name: "Perplexity",
            defaultModel: "sonar",
            placeholder: "pplx-...",
            service: "Fluenta.Perplexity",
            endpoint: "https://api.perplexity.ai/chat/completions"
        ),
        openAICompatible(
            id: "together",
            name: "Together AI",
            defaultModel: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
            placeholder: "...",
            service: "Fluenta.Together",
            endpoint: "https://api.together.xyz/v1/chat/completions"
        ),
        openAICompatible(
            id: "cerebras",
            name: "Cerebras",
            defaultModel: "llama3.1-8b",
            placeholder: "csk-...",
            service: "Fluenta.Cerebras",
            endpoint: "https://api.cerebras.ai/v1/chat/completions"
        )
    ]

    public static func preset(id: String) -> LLMProviderPreset {
        all.first { $0.id == id } ?? .openAI
    }

    private static func openAICompatible(
        id: String,
        name: String,
        defaultModel: String,
        placeholder: String,
        service: String,
        endpoint: String
    ) -> LLMProviderPreset {
        LLMProviderPreset(
            id: id,
            name: name,
            defaultModel: defaultModel,
            apiKeyPlaceholder: placeholder,
            keychainService: service,
            kind: .openAICompatibleChat,
            endpoint: URL(string: endpoint)!
        )
    }
}
