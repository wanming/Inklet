import Foundation

public struct SelectionTranslationService: Sendable {
    public typealias Transform = @Sendable (
        _ sourceText: String,
        _ systemPrompt: String,
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
        self.init { sourceText, systemPrompt, model, temperature, timeoutSeconds in
            let result = try await transformationService.transform(
                sourceText: sourceText,
                mode: Self.promptMode(systemPrompt: systemPrompt),
                model: model,
                temperature: temperature,
                timeoutSeconds: timeoutSeconds
            )
            return result.outputText
        }
    }

    public func translate(
        sourceText: String,
        systemPrompt: String,
        model: String,
        temperature: Double,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        try await transform(sourceText, systemPrompt, model, temperature, timeoutSeconds)
    }

    public static func promptMode(systemPrompt: String) -> PromptMode {
        PromptMode(
            id: "selection-action-translate",
            name: "Selection Action Translate",
            description: "",
            systemPrompt: systemPrompt,
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: 0,
            isVisible: false
        )
    }
}

public struct CachedSelectionTranslationService: Sendable {
    private let service: SelectionTranslationService
    private let cache: JSONSelectionTranslationCache

    public init(
        service: SelectionTranslationService,
        cache: JSONSelectionTranslationCache = JSONSelectionTranslationCache()
    ) {
        self.service = service
        self.cache = cache
    }

    public func translate(
        sourceText: String,
        targetLanguageName: String,
        systemPrompt: String,
        model: String,
        providerID: String,
        temperature: Double,
        timeoutSeconds: TimeInterval,
        now: Date = Date()
    ) async throws -> String {
        let cacheKey = SelectionTranslationCacheKey(
            sourceText: sourceText,
            targetLanguageName: targetLanguageName,
            systemPrompt: systemPrompt,
            model: model,
            providerID: providerID,
            temperature: temperature
        )

        if let cachedTranslation = try? cache.translation(for: cacheKey, now: now) {
            return cachedTranslation
        }

        let translated = try await service.translate(
            sourceText: sourceText,
            systemPrompt: systemPrompt,
            model: model,
            temperature: temperature,
            timeoutSeconds: timeoutSeconds
        )
        try? cache.storeTranslation(translated, for: cacheKey, now: now)
        return translated
    }
}
