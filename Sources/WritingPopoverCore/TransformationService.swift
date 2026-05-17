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
        let nanoseconds = UInt64(max(seconds, 0.001) * 1_000_000_000)
        let operationTask = Task {
            try await operation()
        }
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw TransformationError.timeout
        }

        return try await withCheckedThrowingContinuation { continuation in
            let race = TimeoutRaceState(continuation: continuation)

            Task {
                do {
                    let result = try await operationTask.value
                    if race.resolve(with: .success(result)) {
                        timeoutTask.cancel()
                    }
                } catch {
                    if race.resolve(with: .failure(error)) {
                        timeoutTask.cancel()
                    }
                }
            }

            Task {
                do {
                    _ = try await timeoutTask.value
                } catch {
                    if race.resolve(with: .failure(error)) {
                        operationTask.cancel()
                    }
                }
            }
        }
    }
}

private final class TimeoutRaceState<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resolve(with result: Result<T, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let continuation else {
            return false
        }
        self.continuation = nil

        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
        return true
    }
}
