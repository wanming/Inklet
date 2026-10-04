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

    public init(
        outputText: String,
        providerMetadata: [String: String],
        elapsedMilliseconds: Int
    ) {
        self.outputText = outputText
        self.providerMetadata = providerMetadata
        self.elapsedMilliseconds = elapsedMilliseconds
    }
}

public protocol LLMProvider: Sendable {
    func transform(_ request: TransformationRequest) async throws -> TransformationResult

    /// Reports the output received so far through `onPartialOutput` while the response is generated.
    func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult
}

extension LLMProvider {
    /// Providers without streaming support return the complete result without partial updates.
    public func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        try await transform(request)
    }
}

public enum TransformationError: Error, Equatable, LocalizedError {
    case emptySource
    case emptyResponse
    case timeout
    case networkConnectionLost
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
        case .provider(let message):
            message
        }
    }
}
