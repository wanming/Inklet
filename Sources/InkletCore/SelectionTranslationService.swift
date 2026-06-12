import Foundation

public struct SelectionTranslationService: Sendable {
    public typealias Transform = @Sendable (
        _ sourceText: String,
        _ targetLanguageName: String,
        _ model: String,
        _ temperature: Double,
        _ timeoutSeconds: TimeInterval
    ) async throws -> String

    private let transform: Transform

    public init(transform: @escaping Transform) {
        self.transform = transform
    }

    public init(provider: any LLMProvider) {
        let transformationService = TransformationService(provider: provider)
        self.init { sourceText, targetLanguageName, model, temperature, timeoutSeconds in
            let result = try await transformationService.transform(
                sourceText: sourceText,
                mode: Self.promptMode(targetLanguageName: targetLanguageName),
                model: model,
                temperature: temperature,
                timeoutSeconds: timeoutSeconds
            )
            return result.outputText
        }
    }

    public func translate(
        sourceText: String,
        targetLanguageName: String,
        model: String,
        temperature: Double,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        try await transform(sourceText, targetLanguageName, model, temperature, timeoutSeconds)
    }

    public static func promptMode(targetLanguageName: String) -> PromptMode {
        PromptMode(
            id: "selection-action-translate",
            name: "Selection Action Translate",
            description: "",
            systemPrompt: """
            Translate the user's selected text into \(targetLanguageName).
            Preserve the original meaning, names, numbers, formatting, and tone.
            Do not add explanations, alternatives, quotes, markdown, or commentary.
            Return only the translated text.
            """,
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: 0,
            isVisible: false
        )
    }
}
