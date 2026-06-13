import Foundation

public struct SelectionActionsConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var translationLanguage: SelectionTranslationLanguage
    public var pronunciationVoice: SelectionPronunciationVoice

    public init(
        isEnabled: Bool = true,
        translationLanguage: SelectionTranslationLanguage = .followInterfaceLanguage,
        pronunciationVoice: SelectionPronunciationVoice = .alloy
    ) {
        self.isEnabled = isEnabled
        self.translationLanguage = translationLanguage
        self.pronunciationVoice = pronunciationVoice
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case translationLanguage
        case pronunciationVoice
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultConfig()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        translationLanguage = try container.decodeIfPresent(
            SelectionTranslationLanguage.self,
            forKey: .translationLanguage
        ) ?? defaults.translationLanguage
        pronunciationVoice = try container.decodeIfPresent(
            SelectionPronunciationVoice.self,
            forKey: .pronunciationVoice
        ) ?? defaults.pronunciationVoice
    }

    public static func defaultConfig() -> SelectionActionsConfig {
        SelectionActionsConfig()
    }
}

public enum SelectionPronunciationVoice: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case alloy
    case ash
    case ballad
    case coral
    case echo
    case fable
    case nova
    case onyx
    case sage
    case shimmer
    case verse
    case marin
    case cedar

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    public static func previewText(interfaceLanguageCode: String) -> String {
        let normalized = interfaceLanguageCode.lowercased()
        if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
            return "這是 Inklet。"
        }
        if normalized.hasPrefix("zh") { return "这是 Inklet。" }
        if normalized.hasPrefix("ja") { return "Inklet です。" }
        if normalized.hasPrefix("ko") { return "Inklet입니다." }
        if normalized.hasPrefix("es") { return "Esto es Inklet." }
        if normalized.hasPrefix("fr") { return "Voici Inklet." }
        if normalized.hasPrefix("de") { return "Das ist Inklet." }
        if normalized.hasPrefix("pt") { return "Este e o Inklet." }
        if normalized.hasPrefix("it") { return "Questo e Inklet." }
        return "This is Inklet."
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
