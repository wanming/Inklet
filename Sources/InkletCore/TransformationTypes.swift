import Foundation

public struct TransformationRequest: Equatable, Sendable {
    public var sourceText: String
    public var systemPrompt: String
    public var modeID: String
    public var modeName: String
    public var model: String
    public var timeoutSeconds: TimeInterval

    public init(
        sourceText: String,
        systemPrompt: String,
        modeID: String,
        modeName: String,
        model: String,
        timeoutSeconds: TimeInterval
    ) {
        self.sourceText = sourceText
        self.systemPrompt = systemPrompt
        self.modeID = modeID
        self.modeName = modeName
        self.model = model
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct TransformationResult: Equatable, Sendable {
    public var outputText: String
    public var providerMetadata: [String: String]
    public var elapsedMilliseconds: Int
    /// The model stopped because it reached its output limit, so the end of the reply is missing.
    public var wasTruncated: Bool

    public init(
        outputText: String,
        providerMetadata: [String: String],
        elapsedMilliseconds: Int,
        wasTruncated: Bool = false
    ) {
        self.outputText = outputText
        self.providerMetadata = providerMetadata
        self.elapsedMilliseconds = elapsedMilliseconds
        self.wasTruncated = wasTruncated
    }
}

public protocol LLMProvider: Sendable {
    func transform(_ request: TransformationRequest) async throws -> TransformationResult

    /// Reports the output received so far through `onPartialOutput` while the response is generated.
    func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult

    /// Loads `model` ahead of the first request where that is slow, as it is for local models.
    func warmUp(model: String) async
}

extension LLMProvider {
    /// Providers without streaming support return the complete result without partial updates.
    public func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        try await transform(request)
    }

    /// Cloud providers have nothing to load.
    public func warmUp(model: String) async {}
}

public enum TransformationError: Error, Equatable, LocalizedError {
    case emptySource
    case emptyResponse
    case timeout
    case networkConnectionLost
    /// The source text doesn't fit in the model's context.
    case contextTooLong
    case provider(String)

    public var errorDescription: String? {
        switch self {
        case .emptySource:
            "请输入要转换的文本"
        case .emptyResponse:
            "模型返回了空内容"
        case .timeout:
            "请求超时，请稍后重试"
        case .networkConnectionLost:
            "网络连接中断，请重试"
        case .contextTooLong:
            "原文太长，超出了模型能处理的长度"
        case .provider(let message):
            message
        }
    }
}

/// Recognizes the errors providers return when the request doesn't fit in the model's context, so
/// the person sees why instead of a raw provider message.
enum ContextLimitError {
    private static let markers = [
        "context_length_exceeded",
        "exceed_context_size",
        "maximum context length",
        "context length",
        "context size",
        "prompt is too long",
        "exceeds the maximum number of tokens"
    ]

    static func matches(responseBody data: Data) -> Bool {
        guard let body = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return markers.contains { body.contains($0) }
    }
}
