import Foundation

public struct SelectionTranslation: Equatable, Sendable {
    public var text: String
    /// The model stopped at its output limit, so the end of the translation is missing.
    public var wasTruncated: Bool

    public init(text: String, wasTruncated: Bool = false) {
        self.text = text
        self.wasTruncated = wasTruncated
    }
}

public struct SelectionTranslationService: Sendable {
    public typealias Transform = @Sendable (
        _ sourceText: String,
        _ systemPrompt: String,
        _ model: String,
        _ timeoutSeconds: TimeInterval
    ) async throws -> String

    private typealias TranslationTransform = @Sendable (
        _ sourceText: String,
        _ systemPrompt: String,
        _ model: String,
        _ timeoutSeconds: TimeInterval
    ) async throws -> SelectionTranslation

    private let transform: TranslationTransform

    public init(transform: @escaping Transform) {
        self.transform = { sourceText, systemPrompt, model, timeoutSeconds in
            SelectionTranslation(text: try await transform(sourceText, systemPrompt, model, timeoutSeconds))
        }
    }

    public init(provider: any LLMProvider) {
        let transformationService = TransformationService(provider: provider)
        self.transform = { sourceText, systemPrompt, model, timeoutSeconds in
            let result = try await transformationService.transform(
                sourceText: sourceText,
                mode: Self.promptMode(systemPrompt: systemPrompt),
                model: model,
                timeoutSeconds: timeoutSeconds
            )
            return SelectionTranslation(text: result.outputText, wasTruncated: result.wasTruncated)
        }
    }

    public func translate(
        sourceText: String,
        systemPrompt: String,
        model: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        try await translation(
            sourceText: sourceText,
            systemPrompt: systemPrompt,
            model: model,
            timeoutSeconds: timeoutSeconds
        ).text
    }

    public func translation(
        sourceText: String,
        systemPrompt: String,
        model: String,
        timeoutSeconds: TimeInterval
    ) async throws -> SelectionTranslation {
        try await transform(sourceText, systemPrompt, model, timeoutSeconds)
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
        timeoutSeconds: TimeInterval,
        now: Date = Date()
    ) async throws -> String {
        try await translation(
            sourceText: sourceText,
            targetLanguageName: targetLanguageName,
            systemPrompt: systemPrompt,
            model: model,
            providerID: providerID,
            timeoutSeconds: timeoutSeconds,
            now: now
        ).text
    }

    /// A translation cut off at the output limit isn't cached, so translating again can finish it.
    public func translation(
        sourceText: String,
        targetLanguageName: String,
        systemPrompt: String,
        model: String,
        providerID: String,
        timeoutSeconds: TimeInterval,
        now: Date = Date()
    ) async throws -> SelectionTranslation {
        let cacheKey = SelectionTranslationCacheKey(
            sourceText: sourceText,
            targetLanguageName: targetLanguageName,
            systemPrompt: systemPrompt,
            model: model,
            providerID: providerID
        )

        if let cachedTranslation = try? cache.translation(for: cacheKey, now: now) {
            // Translations cached before Markdown was cleaned up still carry it.
            return SelectionTranslation(text: PlainTextOutput.clean(
                cachedTranslation,
                sourceText: sourceText,
                systemPrompt: systemPrompt
            ))
        }

        let translated = try await service.translation(
            sourceText: sourceText,
            systemPrompt: systemPrompt,
            model: model,
            timeoutSeconds: timeoutSeconds
        )
        if !translated.wasTruncated {
            try? cache.storeTranslation(translated.text, for: cacheKey, now: now)
        }
        return translated
    }
}
