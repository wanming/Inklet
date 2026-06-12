import Foundation

public struct SelectionActionsConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var translationLanguage: SelectionTranslationLanguage

    public init(
        isEnabled: Bool = true,
        translationLanguage: SelectionTranslationLanguage = .followInterfaceLanguage
    ) {
        self.isEnabled = isEnabled
        self.translationLanguage = translationLanguage
    }

    public static func defaultConfig() -> SelectionActionsConfig {
        SelectionActionsConfig()
    }
}

public enum SelectionTranslationLanguage: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case followInterfaceLanguage
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case spanish
    case french
    case german
    case portuguese
    case italian

    public var id: String { rawValue }

    public var promptTargetName: String {
        switch self {
        case .followInterfaceLanguage:
            "English"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        case .traditionalChinese:
            "Traditional Chinese"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        case .spanish:
            "Spanish"
        case .french:
            "French"
        case .german:
            "German"
        case .portuguese:
            "Portuguese"
        case .italian:
            "Italian"
        }
    }

    public func resolvedPromptTargetName(interfaceLanguageCode: String) -> String {
        guard self == .followInterfaceLanguage else {
            return promptTargetName
        }

        let normalized = interfaceLanguageCode.lowercased()
        if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
            return SelectionTranslationLanguage.traditionalChinese.promptTargetName
        }
        if normalized.hasPrefix("zh") { return SelectionTranslationLanguage.simplifiedChinese.promptTargetName }
        if normalized.hasPrefix("ja") { return SelectionTranslationLanguage.japanese.promptTargetName }
        if normalized.hasPrefix("ko") { return SelectionTranslationLanguage.korean.promptTargetName }
        if normalized.hasPrefix("es") { return SelectionTranslationLanguage.spanish.promptTargetName }
        if normalized.hasPrefix("fr") { return SelectionTranslationLanguage.french.promptTargetName }
        if normalized.hasPrefix("de") { return SelectionTranslationLanguage.german.promptTargetName }
        if normalized.hasPrefix("pt") { return SelectionTranslationLanguage.portuguese.promptTargetName }
        if normalized.hasPrefix("it") { return SelectionTranslationLanguage.italian.promptTargetName }
        return SelectionTranslationLanguage.english.promptTargetName
    }
}
