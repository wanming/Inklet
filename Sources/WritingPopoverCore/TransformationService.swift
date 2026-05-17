import Foundation

public struct TransformationService: Sendable {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func transform(
        sourceText: String,
        mode: PromptMode,
        model: String,
        temperature: Double,
        timeoutSeconds: TimeInterval
    ) async throws -> TransformationResult {
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw TransformationError.emptySource
        }

        let request = TransformationRequest(
            sourceText: trimmedSource,
            systemPrompt: mode.systemPrompt,
            modeID: mode.id,
            modeName: mode.name,
            model: model,
            temperature: temperature,
            timeoutSeconds: timeoutSeconds
        )

        let result = try await withTimeout(seconds: timeoutSeconds) {
            try await provider.transform(request)
        }
        let trimmedOutput = result.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            throw TransformationError.emptyResponse
        }

        return TransformationResult(
            outputText: trimmedOutput,
            providerMetadata: result.providerMetadata,
            elapsedMilliseconds: result.elapsedMilliseconds
        )
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(max(seconds, 0.001) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw TransformationError.timeout
            }

            guard let result = try await group.next() else {
                throw TransformationError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}
